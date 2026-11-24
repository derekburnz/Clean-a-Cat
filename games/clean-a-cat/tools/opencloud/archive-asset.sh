#!/usr/bin/env bash
# Archive Roblox assets by id (Open Cloud Assets API, POST /assets/v1/assets/{id}:archive), for uploads that were
# replaced and should leave the group's inventory, such as an old icon. An archived asset stops loading in games and
# can be restored later (Creator Dashboard, or POST .../assets/{id}:restore). Run by
# .github/workflows/archive-asset.yml; also works from Git Bash on a PC with the same variable set.
# Open Cloud does not archive every type: an Image is refused with HTTP 400 "is not an archivable asset type"
# (2026-11-24, #275); archive those by hand in the Creator Dashboard.
#
#   ROBLOX_UPLOAD_KEY  Open Cloud API key with asset:read and asset:write, created by the asset's owner (the same key
#                      upload-asset uses; docs/setup-guide.md step 8)
#
# Usage:  archive-asset.sh <asset id> [<asset id> ...]
# Each id is read first, so the log shows its name, type and owner before it is archived. One id that fails does not
# stop the rest; the script fails at the end if any did. Needs curl and jq.
set -euo pipefail

: "${ROBLOX_UPLOAD_KEY:?set ROBLOX_UPLOAD_KEY (docs/setup-guide.md step 8)}"
[ "$#" -gt 0 ] || {
	echo "no asset ids given" >&2
	exit 2
}
for id in "$@"; do
	case "$id" in
	'' | *[!0-9]*)
		echo "an asset id is digits only, got: $id" >&2
		exit 2
		;;
	esac
done

API=https://apis.roblox.com/assets/v1
reply=$(mktemp)
trap 'rm -f "$reply"' EXIT

# call url [curl args...] -> sets $status and $body; 5xx and 429 get three more tries over about half a minute.
call() {
	local url=$1 wait
	shift
	for wait in 5 10 20 0; do
		status=$(curl -sS -o "$reply" -w '%{http_code}' "$url" -H "x-api-key: $ROBLOX_UPLOAD_KEY" "$@") || status=000
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

failed=0
for id in "$@"; do
	call "$API/assets/$id?readMask=displayName,assetType,state,creationContext"
	if [ "$status" != 200 ]; then
		echo "::error::$id: could not read it (HTTP $status): $body"
		case "$status" in
		401 | 403) echo "The key needs asset:read and asset:write, created by the asset's owner." >&2 ;;
		esac
		failed=$((failed + 1))
		continue
	fi
	name=$(jq -r '.displayName // "?"' <<<"$body")
	type=$(jq -r '.assetType // "?"' <<<"$body")
	state=$(jq -r '.state // "?"' <<<"$body")
	# a group id is public; a user id stays out of the public Actions log
	owner=$(jq -r '.creationContext.creator | if .groupId then "group \(.groupId)" else "a user" end' <<<"$body")
	echo "$id: $type \"$name\", owned by $owner, state $state"
	if [ "$state" = Archived ]; then
		echo "$id is already archived."
		continue
	fi
	call "$API/assets/$id:archive" -X POST -H "Content-Type: application/json" -d '{}'
	if [ "$status" != 200 ]; then
		echo "::error::$id: archive refused (HTTP $status): $body"
		failed=$((failed + 1))
		continue
	fi
	echo "Archived $id ($type \"$name\", $owner). To undo: POST $API/assets/$id:restore"
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		echo "- archived **$id**: $type \"$name\", $owner" >>"$GITHUB_STEP_SUMMARY"
	fi
done
if [ "$failed" -gt 0 ]; then
	echo "::error::$failed asset(s) were not archived; see the log above"
	exit 1
fi
