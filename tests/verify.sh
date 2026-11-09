#!/usr/bin/env bash
# Build the debug GDExtension and run every headless test script.
# Usage (repo root, Git Bash on Windows):  bash tests/verify.sh [--no-build] [test.gd ...]
# Exit 0 only when the build succeeds and every test script exits 0.
#
# Test scripts: tests/offline_render.gd, tests/smoke.gd and every tests/test_*.gd.
# Each one `extends SceneTree`, prints PASS/FAIL lines and calls quit(1) on any failure.
# Pass explicit script paths (relative to the repo root) to run only those.
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT_BIN:-/c/Godot/4.7/Godot_v4.7-stable_win64_console.exe}"
PY="${PYTHON_BIN:-/c/Python314/python}"
[ -x "$PY" ] || PY=python

build=1
scripts=()
for a in "$@"; do
	case "$a" in
		--no-build) build=0 ;;
		*) scripts+=("$a") ;;
	esac
done

if [ "$build" -eq 1 ]; then
	# Git Bash's MSYS tools and MSYSTEM confuse SCons's MSVC detection: strip them.
	CLEAN=$(echo "$PATH" | tr ':' '\n' | grep -v -E '^/(usr/|bin|mingw64|clangarm64|ucrt64)' | grep -v -i '/Git/' | paste -sd:)
	LOG=$(mktemp)
	if ! env -u MSYSTEM -u SHELL PATH="$CLEAN" "$PY" -m SCons target=template_debug -j8 >"$LOG" 2>&1; then
		echo "BUILD FAILED (last 40 lines):"
		tail -40 "$LOG"
		exit 1
	fi
	echo "build ok"
fi

# Godot only loads GDExtensions listed in .godot/extension_list.cfg, so import first.
timeout 300 "$GODOT" --headless --path project --import >/dev/null 2>&1 || true

if [ "${#scripts[@]}" -eq 0 ]; then
	scripts=(tests/offline_render.gd tests/smoke.gd)
	for f in tests/test_*.gd; do
		[ -e "$f" ] && scripts+=("$f")
	done
fi

fail=0
for s in "${scripts[@]}"; do
	OUT=$(mktemp)
	timeout 300 "$GODOT" --headless --audio-driver Dummy --path project -s "../$s" >"$OUT" 2>&1
	code=$?
	if [ "$code" -ne 0 ] || grep -q -E '^(FAIL|SCRIPT ERROR|Parse Error)' "$OUT"; then
		echo "FAILED: $s (exit $code)"
		grep -E 'FAIL|ERROR|Error' "$OUT" | head -40
		fail=1
	else
		echo "ok: $s ($(grep -c '^PASS' "$OUT") checks)"
	fi
done
exit $fail
