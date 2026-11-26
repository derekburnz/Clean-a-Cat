#!/usr/bin/env bash
# The one check every thread runs before `git push` (CLAUDE.md, "Before every push"). It runs what GitHub runs on a
# pull request, against the branch merged with the newest main, so a push that passes here passes there:
#   1. merges origin/main into the branch (GitHub tests the PR merged with main; stops on a conflict)
#   2. the gate job: check.sh with the exact tool versions pinned in rokit.toml (rojo, luau-lsp, selene, stylua)
#   3. the tests job: tools/cloudcheck strict types, unit tests and the UI gate (phones and tablets)
#
# Works on a cloud thread with no Rokit: missing tools are fetched once from their GitHub release pages at the
# rokit.toml versions into ~/.cache/cleanacat-tools/<tool>-<version>. On a PC with Rokit, Rokit's own tools are used.
# Selene needs Roblox's API list (roblox.yml). Where the network blocks Selene's own fetch (cloud threads), the copy
# main keeps is downloaded; only when that fails too is Selene skipped with a warning. Every other step must pass.
#
#   bash games/clean-a-cat/tools/prepush.sh            # from anywhere in the repo
#   bash games/clean-a-cat/tools/prepush.sh --no-merge # skip step 1 (only when main was merged a moment ago)
#   bash games/clean-a-cat/tools/prepush.sh --quick    # skip the UI gate (code that never touches src/client/UI)
set -euo pipefail

MERGE=1
QUICK=0
for arg in "$@"; do
	case "$arg" in
	--no-merge) MERGE=0 ;;
	--quick) QUICK=1 ;;
	*)
		echo "unknown option $arg" >&2
		exit 2
		;;
	esac
done

ROOT=$(git rev-parse --show-toplevel)
GAME="$ROOT/games/clean-a-cat"
cd "$ROOT"

# GitHub tests the commit, not this folder: a change not committed (or a new file not added) would pass here only
if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
	echo "Uncommitted or untracked files. Commit (or stash) them first, so this checks what you will push:" >&2
	git status --short >&2
	exit 1
fi

# 1. Newest main, as GitHub will test it
if [ "$MERGE" = 1 ]; then
	echo "== merge origin/main"
	git fetch -q origin main
	if ! git merge --no-edit -q origin/main; then
		echo "Merge with main has conflicts. Resolve them (or git merge --abort), then run this again." >&2
		exit 1
	fi
fi

# 2. The pinned tools
pinned() { grep -E "^$1 *=" "$ROOT/rokit.toml" | sed -E 's/.*@([0-9.]+)".*/\1/'; }
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/cleanacat-tools"
fetch() { # tool version url binary
	local dir="$CACHE/$1-$2"
	if [ ! -x "$dir/$4" ]; then
		echo "Fetching $1 $2 (once)..."
		mkdir -p "$dir"
		curl -fsSL -o "$dir/tool.zip" "$3"
		(cd "$dir" && unzip -oq tool.zip && rm -f tool.zip && chmod +x "$4")
	fi
	PATH="$dir:$PATH"
}
want() { # tool version: true when the tool on PATH is missing or another version
	! command -v "$1" >/dev/null 2>&1 || ! "$1" --version 2>/dev/null | grep -qFw "$2"
}
OS=$(uname -s)
if [ "$OS" = "Linux" ]; then
	V=$(pinned rojo)
	want rojo "$V" && fetch rojo "$V" "https://github.com/rojo-rbx/rojo/releases/download/v$V/rojo-$V-linux-x86_64.zip" rojo
	V=$(pinned luau-lsp)
	want luau-lsp "$V" && fetch luau-lsp "$V" "https://github.com/JohnnyMorganz/luau-lsp/releases/download/$V/luau-lsp-linux-x86_64.zip" luau-lsp
	V=$(pinned selene)
	want selene "$V" && fetch selene "$V" "https://github.com/Kampfkarren/selene/releases/download/$V/selene-$V-linux.zip" selene
	V=$(pinned stylua)
	want stylua "$V" && fetch stylua "$V" "https://github.com/JohnnyMorganz/StyLua/releases/download/v$V/stylua-linux-x86_64.zip" stylua
	export PATH
fi
for t in rojo luau-lsp selene stylua; do
	V=$(pinned "$t")
	if want "$t" "$V"; then
		echo "$t $V is not on PATH. On a PC run 'rokit install' in the repo root (docs/setup-guide.md)." >&2
		exit 1
	fi
done

# The gate job, as CI runs it. Selene alone may be skipped when Roblox's API list cannot be fetched.
cd "$GAME"
# a cloud thread cannot generate Selene's Roblox list itself: take the copy main's check run keeps as the asset
# roblox.yml of the GitHub release selene-std (check.yml, job keep-selene-std; run artifacts are not reachable from a
# cloud thread). Taken again once a day, and an old copy is replaced only when the new download worked.
if ! [ -f roblox.yml ] || [ -n "$(find roblox.yml -mmin +1440 2>/dev/null)" ]; then
	if command -v gh >/dev/null 2>&1; then
		ASSET=$(gh api repos/derekburnz/Clean-a-Cat/releases/tags/selene-std \
			-q '.assets[] | select(.name == "roblox.yml") | .url' 2>/dev/null || true)
		if [ -n "$ASSET" ]; then
			NEW=$(mktemp)
			if gh api -H "Accept: application/octet-stream" "$ASSET" >"$NEW" 2>/dev/null && [ -s "$NEW" ]; then
				mv "$NEW" roblox.yml
			else
				rm -f "$NEW"
			fi
		fi
	fi
fi
if ! [ -f roblox.yml ] && ! selene generate-roblox-std >/dev/null 2>&1; then
	echo "WARNING: Selene skipped (no Roblox list: blocked here and none kept on main yet); GitHub runs it, so a lint error can still go red."
	TMP_CHECK=$(mktemp)
	trap 'rm -f "$TMP_CHECK"' EXIT
	sed -e 's/^step "selene" selene src$/echo "== selene skipped"/' -e "s|^cd \"\$(dirname \"\$0\")\"\$|cd \"$GAME\"|" check.sh >"$TMP_CHECK"
	bash "$TMP_CHECK"
else
	bash ./check.sh
fi

# 3. The tests job
cd "$GAME/tools/cloudcheck"
# a fresh install when the lock file changed (for example with the merge of main) since the last one
if [ ! -d node_modules ] || [ package-lock.json -nt node_modules/.package-lock.json ]; then
	npm ci --silent
fi
echo "== strict types"
node analyze.mjs --tests
echo "== unit tests"
node run-tests.mjs
if [ "$QUICK" = 0 ]; then
	echo "== UI gate"
	node uigate.mjs --out "${TMPDIR:-/tmp}/uigate"
	node uigate.mjs --tablets --out "${TMPDIR:-/tmp}/uigate-tablets"
fi
echo "Pre-push check passed. Push now, before main moves again."
