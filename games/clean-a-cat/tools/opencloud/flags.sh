#!/usr/bin/env bash
# Read or change the live switches (src/shared/LiveFlags.luau) in their DataStore, so a feature can be turned on
# or off in every running server within about a minute, with no publish and no restart.
# Every switch lives in one entry (LiveFlags.ALL_ENTRY, a JSON object keyed by switch name), which servers read once
# a minute (#325). Each change is read, changed and written back with the entry's etag. Until every experience runs
# servers that read that entry, each change is also written to the switch's own older entry, which older servers
# read; the first change (or "migrate") builds the one entry from those older entries.
# Run by .github/workflows/flags.yml; also works from Git Bash with the same variables. Needs curl and jq.
#
#   ROBLOX_PUBLISH_KEY   Open Cloud key with universe-datastores.objects:read, :create and :update
#   UNIVERSE_ID          the experience id (not secret)
#   STORE_SUFFIX         optional: "_dev" for the switches Studio playtests read
#
# Usage:  flags.sh show | set <switch> true|false | clear <switch> | migrate
#   clear takes the switch out, which puts it back at its default.
#   migrate rebuilds the one entry from the older per-switch entries (set and clear do it when it is missing).
set -euo pipefail

: "${ROBLOX_PUBLISH_KEY:?set ROBLOX_PUBLISH_KEY (docs/setup-guide.md step 8)}"
: "${UNIVERSE_ID:?set UNIVERSE_ID to the experience id}"

LIVEFLAGS=${LIVEFLAGS:-$(dirname "$0")/../../src/shared/LiveFlags.luau}
[ -f "$LIVEFLAGS" ] || { echo "LiveFlags.luau not found at $LIVEFLAGS" >&2; exit 1; }
STORE=$(grep -oE '^LiveFlags\.STORE = "[A-Za-z0-9_]+"' "$LIVEFLAGS" | grep -oE '"[A-Za-z0-9_]+"' | tr -d '"')
[ -n "$STORE" ] || { echo "LiveFlags.STORE not found in $LIVEFLAGS" >&2; exit 1; }
# Studio playtests read the store with "_dev" after its name (LiveFlagService), so STORE_SUFFIX=_dev sets those.
STORE=$STORE${STORE_SUFFIX:-}
ALL=$(grep -oE '^LiveFlags\.ALL_ENTRY = "[A-Za-z0-9_]+"' "$LIVEFLAGS" | grep -oE '"[A-Za-z0-9_]+"' | tr -d '"')
[ -n "$ALL" ] || { echo "LiveFlags.ALL_ENTRY not found in $LIVEFLAGS" >&2; exit 1; }
mapfile -t KEYS < <(awk '/^LiveFlags.KEYS = \{/{on=1;next} on&&/^\}/{exit} on' "$LIVEFLAGS" | grep -o '^[[:space:]]*"[A-Za-z0-9]*"' | tr -d ' \t"')
mapfile -t OFF_KEYS < <(awk '/^LiveFlags.OFF_BY_DEFAULT = \{/{on=1;next} on&&/^\}/{exit} on' "$LIVEFLAGS" | grep -o '^[[:space:]]*[A-Za-z0-9]* = true' | awk '{print $1}')
[ "${#KEYS[@]}" -gt 0 ] || { echo "no switches read from $LIVEFLAGS" >&2; exit 1; }
entries=https://apis.roblox.com/cloud/v2/universes/$UNIVERSE_ID/data-stores/$STORE/entries

usage() {
	echo "usage: flags.sh show | set <switch> true|false | clear <switch> | migrate" >&2
	echo "switches (src/shared/LiveFlags.luau KEYS): ${KEYS[*]}" >&2
	exit 2
}
is_key() {
	local k
	for k in "${KEYS[@]}"; do [ "$k" = "$1" ] && return 0; done
	return 1
}
starts_off() {
	local k
	for k in "${OFF_KEYS[@]}"; do [ "$k" = "$1" ] && return 0; done
	return 1
}

reply=$(mktemp)
trap 'rm -f "$reply"' EXIT
call() {
	local method=$1 url=$2 wait
	shift 2
	for wait in 5 10 20 0; do
		status=$(curl -sS -o "$reply" -w '%{http_code}' -X "$method" "$url" -H "x-api-key: $ROBLOX_PUBLISH_KEY" "$@") ||
			status=000
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
fail() {
	echo "Open Cloud answered HTTP $status: $body" >&2
	case "$status" in
	401 | 403) echo "The key needs universe-datastores.objects:read, :create and :update on universe $UNIVERSE_ID (docs/setup-guide.md step 8)." >&2 ;;
	esac
	exit 1
}

# The one entry: ALL_VALUE is its JSON object ("" when it is missing or not an object), ALL_ETAG its etag.
load_all() {
	call GET "$entries/$ALL"
	ALL_VALUE="" ALL_ETAG=""
	if [ "$status" = 200 ]; then
		if jq -e '.value | type == "object"' <<<"$body" >/dev/null; then
			ALL_VALUE=$(jq -c '.value' <<<"$body")
		fi
		ALL_ETAG=$(jq -r '.etag // empty' <<<"$body")
	elif [ "$status" != 404 ]; then
		fail
	fi
}
# The one entry built from the older per-switch entries (a missing entry is left out, as it means the default).
build_all() {
	local key value=$'{}'
	for key in "${KEYS[@]}"; do
		call GET "$entries/$key"
		if [ "$status" = 200 ]; then
			value=$(jq -c --arg k "$key" --argjson v "$(jq -c '.value' <<<"$body")" '.[$k] = $v' <<<"$value")
		elif [ "$status" != 404 ]; then
			fail
		fi
	done
	echo "Built $ALL from the per-switch entries: $value" >&2
	ALL_VALUE=$value
}
# Writes $1 as the one entry. With an etag, Open Cloud refuses the write if the entry changed since it was read.
write_all() {
	local data
	data=$(jq -cn --argjson v "$1" --arg e "$ALL_ETAG" 'if $e == "" then {value: $v} else {value: $v, etag: $e} end')
	call PATCH "$entries/$ALL?allowMissing=true" -H "Content-Type: application/json" --data "$data"
	if [ "$status" != 200 ]; then
		echo "Could not write $ALL. If Open Cloud says it changed since it was read, run the flags workflow again." >&2
		fail
	fi
	ALL_VALUE=$1
	ALL_ETAG=$(jq -r '.etag // empty' <<<"$body")
}
# Loads the one entry, building it from the older entries when it is missing.
ensure_all() {
	load_all
	[ -n "$ALL_VALUE" ] || build_all
}

meaning_of() {
	local key=$1 raw=$2
	if starts_off "$key"; then
		if [ "$raw" = true ]; then echo "ON in every server"; else echo "off (its default)"; fi
	elif [ "$raw" = false ]; then
		echo "OFF in every server"
	else
		echo "on (its default)"
	fi
}
# One switch as servers read it: from the one entry when it exists, else from its own older entry. With $2 = "both",
# also reads the older entry and says when it differs (servers on older code still read that one).
show_key() {
	local key=$1 raw old="" note=""
	if [ -n "$ALL_VALUE" ]; then
		raw=$(jq -c --arg k "$key" 'if has($k) then .[$k] else "(no entry)" end' <<<"$ALL_VALUE" | sed 's/^"(no entry)"$/(no entry)/')
	fi
	if [ -z "$ALL_VALUE" ] || [ "${2:-}" = both ]; then
		call GET "$entries/$key"
		if [ "$status" = 404 ]; then
			old="(no entry)"
		elif [ "$status" = 200 ]; then
			old=$(jq -c '.value' <<<"$body")
		else
			fail
		fi
		if [ -z "$ALL_VALUE" ]; then
			raw=$old
		elif [ "$old" != "$raw" ]; then
			note="; its older entry says $old"
		fi
	fi
	echo "$key = $raw ($(meaning_of "$key" "$raw"))$note"
	[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "- \`$key\` = \`$raw\`: $(meaning_of "$key" "$raw")$note" >>"$GITHUB_STEP_SUMMARY"
}

case "${1:-}" in
show)
	load_all
	if [ -n "$ALL_VALUE" ]; then
		echo "== $STORE, entry $ALL (servers pick a change up within about 60 s)"
	else
		echo "== $STORE, one entry per switch ($ALL not written yet; the first set or migrate writes it)"
	fi
	for key in "${KEYS[@]}"; do show_key "$key" both; done
	;;
set)
	key=${2:-} value=${3:-}
	is_key "$key" || usage
	case "$value" in true | false) ;; *) usage ;; esac
	ensure_all
	write_all "$(jq -c --arg k "$key" --argjson v "$value" '.[$k] = $v' <<<"$ALL_VALUE")"
	# the older entry too, for servers still on code from before #325
	call PATCH "$entries/$key?allowMissing=true" -H "Content-Type: application/json" \
		--data "$(jq -cn --argjson v "$value" '{value: $v}')"
	[ "$status" = 200 ] || fail
	echo "Wrote $key = $value"
	show_key "$key" both
	;;
clear)
	key=${2:-}
	is_key "$key" || usage
	ensure_all
	write_all "$(jq -c --arg k "$key" 'del(.[$k])' <<<"$ALL_VALUE")"
	call DELETE "$entries/$key"
	case "$status" in 200 | 204 | 404) ;; *) fail ;; esac
	echo "Cleared $key"
	show_key "$key" both
	;;
migrate)
	load_all
	build_all
	write_all "$ALL_VALUE"
	echo "Wrote $ALL from the per-switch entries"
	;;
*) usage ;;
esac
