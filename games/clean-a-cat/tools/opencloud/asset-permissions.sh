#!/usr/bin/env bash
# Share the pictures and sounds the game uses with the experience itself, so they keep working when the assets and
# the game have different owners: for example assets uploaded under a person's account while a group owns the game,
# or after the game moves to a group. A sound or picture that is not public loads only in experiences it is shared
# with, so each id gets the "Use" permission for the experience. Run `grant` again after new ids land; ids that
# already have it are fine.
# Run by .github/workflows/asset-permissions.yml; also works from Git Bash on a PC with the same variables set.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud API key with asset-permissions:write, created by the account or group that owns
#                        the assets (docs/setup-guide.md step 8)
#   ROBLOX_UNIVERSE_ID   the experience id
#
# Usage:
#   asset-permissions.sh list     every rbxassetid the shipped game uses (src and the Rojo model files), with its file
#   asset-permissions.sh grant    give the experience Use permission on each of them
#   asset-permissions.sh owners [ref]
#                                 read each id's owner (Open Cloud Assets API, asset:read) and fail unless every one
#                                 is owned by the group GROUP_ID (default 107520049, Creampuff Games). With a git ref
#                                 (check.yml passes the PR's base), only the ids that ref does not have yet are read.
#                                 Reason: a picture, sound or mesh a person's account owns does not load in the
#                                 group's game for players (Derek, 2026-11-27: "make sure assets are being uploaded
#                                 for the group use and not player only so people will actually see them").
# Roblox's Asset Permissions API (beta) cannot take a grant back, which is fine here: the only subject is our own
# experience. Ids the key's owner does not own (a public Roblox asset) are reported and left alone.
# Needs curl and jq (both on GitHub's ubuntu runners).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
UNIVERSE_ID=${ROBLOX_UNIVERSE_ID:-} # grant needs it; list and owners do not
# Who gets Use permission: the experience by default. A user id (SUBJECT_TYPE=User, SUBJECT_ID=<user id>) lets that
# account's Studio load the pictures too: Studio fetches as the signed-in user, not as the experience.
SUBJECT_TYPE=${SUBJECT_TYPE:-Universe}
SUBJECT_ID=${SUBJECT_ID:-$UNIVERSE_ID}
API=https://apis.roblox.com/asset-permissions-api/v1/assets/permissions
BATCH=25 # ids per request; the API allows 100 requests a minute per key owner
# What ships: the Luau code and the Rojo model files. Tests and docs are left out.
SOURCES=(games/clean-a-cat/src assets/clean-a-cat/rbx)

usage() {
	echo "usage: asset-permissions.sh list | grant | owners [git ref]" >&2
	exit 2
}

# One line per id: "<id> <file>", the first file that uses it, sorted by file.
ids_with_files() {
	(cd "$REPO" && grep -rsnoE 'rbxassetid://[0-9]+' "${SOURCES[@]}" || true) |
		sed -E 's#^([^:]+):[0-9]+:rbxassetid://([0-9]+)$#\2 \1#' |
		sort -k1,1 -u | sort -k2,2 -k1,1n
}

list() {
	local lines
	lines=$(ids_with_files)
	[ -n "$lines" ] || {
		echo "No rbxassetid found under ${SOURCES[*]}." >&2
		exit 1
	}
	echo "$lines" | awk '{ print "  " $1 "  " $2 }'
	echo
	echo "$lines" | awk '{ n[$2]++ } END { for (f in n) print n[f] "  " f }' | sort -k2
	echo "$(echo "$lines" | wc -l | tr -d ' ') ids in all."
}

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT
# call body -> sets $status and $body. Roblox answers 5xx or 429 now and then, so those get three more tries.
call() {
	local data=$1 wait
	for wait in 5 10 20 0; do
		status=$(curl -sS -o "$reply" -w '%{http_code}' -X PATCH "$API" -H "x-api-key: $ROBLOX_PUBLISH_KEY" \
			-H "Content-Type: application/json" --data "$data") || status=000
		case "$status" in
		5?? | 429 | 000) ;;
		*) break ;;
		esac
		[ "$wait" = 0 ] && break
		echo "Open Cloud answered HTTP $status; trying again in ${wait}s." >&2
		sleep "$wait"
	done
	body=$(cat "$reply")
}

grant() {
	: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 8)}"
	: "${UNIVERSE_ID:?set ROBLOX_UNIVERSE_ID to the experience id}"
	local lines ids granted=0 notours=0 failed=0 i batch data id code file
	lines=$(ids_with_files)
	mapfile -t ids < <(echo "$lines" | awk '{ print $1 }')
	echo "Giving $SUBJECT_TYPE $SUBJECT_ID Use permission on ${#ids[@]} ids, $BATCH per request."
	for ((i = 0; i < ${#ids[@]}; i += BATCH)); do
		batch=("${ids[@]:i:BATCH}")
		data=$(printf '%s\n' "${batch[@]}" | jq -Rn --arg t "$SUBJECT_TYPE" --arg u "$SUBJECT_ID" \
			'{subjectType: $t, subjectId: $u, action: "Use", requests: [inputs | {assetId: tonumber, grantToDependencies: false}]}')
		call "$data"
		case "$status" in
		200) ;;
		401 | 403)
			echo "Open Cloud answered HTTP $status: $body" >&2
			echo "The key needs asset-permissions:write (docs/setup-guide.md step 8). Nothing more was sent." >&2
			exit 1
			;;
		*)
			echo "Open Cloud answered HTTP $status for ids ${batch[0]} to ${batch[-1]}: $body" >&2
			failed=$((failed + ${#batch[@]}))
			continue
			;;
		esac
		granted=$((granted + $(echo "$body" | jq '.successAssetIds // [] | length')))
		# Per-id errors: the id, Roblox's code and the file that uses it.
		while read -r id code; do
			[ -n "$id" ] || continue
			file=$(echo "$lines" | awk -v id="$id" '$1 == id { print $2; exit }')
			case "$code" in
			PublicAssetCannotBeGrantedTo | CannotManageAsset)
				# Not ours to share: a public asset works in every experience already.
				echo "  $id ($file): $code, not ours to share; it keeps working if it is public."
				notours=$((notours + 1))
				;;
			*)
				echo "::warning::$id ($file): $code"
				failed=$((failed + 1))
				;;
			esac
		done < <(echo "$body" | jq -r '.errors // [] | .[] | "\(.assetId) \(.code)"')
	done
	echo "Granted $granted, not ours $notours, failed $failed, of ${#ids[@]}."
	[ "$failed" = 0 ] || exit 1
}

# owners [ref]: every id (or each one new since `ref`) must be owned by the group GROUP_ID.
owners() {
	local ref=${1:-} group=${GROUP_ID:-107520049} lines ids ingroup=0 bad=0 id file owner wait
	lines=$(ids_with_files)
	if [ -n "$ref" ]; then
		local before
		before=$(cd "$REPO" && git grep -hoE 'rbxassetid://[0-9]+' "$ref" -- "${SOURCES[@]}" 2>/dev/null |
			sed -E 's#^rbxassetid://##' | sort -u || true)
		lines=$(echo "$lines" | awk -v before="$before" 'BEGIN { n = split(before, b, "\n"); for (i = 1; i <= n; i++) old[b[i]] = 1 }
			$1 != "" && !($1 in old)')
	fi
	mapfile -t ids < <(echo "$lines" | awk 'NF { print $1 }')
	if [ "${#ids[@]}" = 0 ]; then
		echo "No new asset ids${ref:+ since $ref}: nothing to check."
		return 0
	fi
	: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY: an Open Cloud key with asset:read (the group key)}"
	echo "Reading the owner of ${#ids[@]} asset id(s)${ref:+ new since $ref}; each must be owned by group $group."
	for id in "${ids[@]}"; do
		file=$(echo "$lines" | awk -v id="$id" '$1 == id { print $2; exit }')
		for wait in 5 10 20 40 0; do
			status=$(curl -sS -o "$reply" -w '%{http_code}' -H "x-api-key: $ROBLOX_PUBLISH_KEY" \
				"https://apis.roblox.com/assets/v1/assets/$id?readMask=creationContext") || status=000
			case "$status" in
			5?? | 429 | 000) ;;
			*) break ;;
			esac
			[ "$wait" = 0 ] && break
			sleep "$wait"
		done
		if [ "$status" = 200 ]; then
			# a group id is public; a user id stays out of the public Actions log
			owner=$(jq -r '.creationContext.creator | if .groupId then "group \(.groupId)" elif .userId then "a user" else "unknown" end' "$reply")
		else
			owner="not readable with the group key (HTTP $status)"
		fi
		if [ "$owner" = "group $group" ]; then
			ingroup=$((ingroup + 1))
		else
			echo "::error file=$file::asset $id ($file) has owner: $owner; it must be group $group. Upload it again with the upload-asset workflow (it uploads to the group), or the players will not see it."
			bad=$((bad + 1))
		fi
		sleep 0.2 # well under the Assets API's read limit
	done
	echo "Owned by group $group: $ingroup. Not the group's: $bad. Of ${#ids[@]}."
	[ "$bad" = 0 ]
}

case "${1:-}" in
list) list ;;
grant) grant ;;
owners) owners "${2:-}" ;;
*) usage ;;
esac
