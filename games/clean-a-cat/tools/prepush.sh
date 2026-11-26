#!/usr/bin/env bash
# The one check every thread runs before `git push` (CLAUDE.md, "Before every push"). It runs what GitHub runs on a
# pull request, against the branch merged with the newest main, so a push that passes here passes there:
#   1. merges origin/main into the branch (GitHub tests the PR merged with main; stops on a conflict)
#   2. the gate job: check.sh with the exact tool versions pinned in rokit.toml (rojo, luau-lsp, selene, stylua)
#   3. the tests job: tools/cloudcheck strict types, unit tests and the UI gate (phones and tablets)
#
# Works on a cloud thread with no Rokit: missing tools are fetched once from their GitHub release pages at the
# rokit.toml versions into ~/.cache/cleanacat-tools/<tool>-<version>. On a PC with Rokit, Rokit's own tools are used.
# Selene needs Roblox's API list on its first run; where the network blocks that (cloud threads), Selene is skipped
# with a warning and GitHub judges it. Every other step must pass.
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
	! command -v "$1" >/dev/null 2>&1 || ! "$1" --version 2>/dev/null | grep -q "$2"
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
if ! [ -f roblox.yml ] && ! selene generate-roblox-std >/dev/null 2>&1; then
	echo "WARNING: Selene skipped (Roblox's API list is blocked here); GitHub runs it."
	sed -e 's/^step "selene" selene src$/echo "== selene skipped"/' -e "s|^cd \"\$(dirname \"\$0\")\"\$|cd \"$GAME\"|" check.sh >"${TMPDIR:-/tmp}/cleanacat-check.sh"
	bash "${TMPDIR:-/tmp}/cleanacat-check.sh"
else
	bash ./check.sh
fi

# 3. The tests job
cd "$GAME/tools/cloudcheck"
[ -d node_modules ] || npm ci --silent
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
