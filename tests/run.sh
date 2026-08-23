#!/usr/bin/env bash
# caxton test runner.
#
# Walks tests/**/*.typ and classifies each file by a header line, same
# convention as vendor/staunton's own tests/run.sh:
#   * a file WITH  "// EXPECT: <substr>"  is an EXPECTED-FAIL test: it must
#     error (exit != 0) AND the error message must contain <substr>.
#   * a file WITHOUT it is an EXPECTED-PASS test: it must compile (exit 0).
#     Its output is kept under tests/out/, mirroring the path below tests/.
#
# Files and directories whose name starts with "_" are skipped (shared
# fixtures, e.g. tests/diagram_points/_fixture.typ).
#
# Most test files call caxton's own PRIVATE (underscore-prefixed) helpers
# directly via `#import "/lib.typ": _diagram-points, ...` -- Typst has no
# real module-level visibility enforcement, so this works exactly like
# vendor/staunton's own tests importing e.g. `_position-after`. This is
# deliberate: testing the actual decision logic (diagram placement, title
# stripping, PGN splitting) directly, with plain #assert(..), is far more
# precise than only compiling full documents and eyeballing output -- the
# handful of true end-to-end tests (multi_game_e2e/, zero_move/end_to_end,
# null_move/, percent_escape_e2e/) exist specifically to catch the
# integration-level crash-class regressions that only surface when
# caxton() runs its full pipeline.
#
# Usage:  bash tests/run.sh [PATH ...]
#   PATH ...   optional path filter(s) -- files or directories under tests/.
#              With no PATH, every test runs.
set -u
cd "$(dirname "$0")/.."
ROOT="."
OUT="tests/out"
mkdir -p "$OUT"

read_expect() {
  want=""
  local line
  while IFS= read -r line; do
    case "$line" in
      "// EXPECT:"*)
        want="${line#// EXPECT:}"
        want="${want#"${want%%[![:space:]]*}"}"   # strip leading whitespace
        break ;;
    esac
  done < "$1"
}

FILTERS=()
for a in "$@"; do
  if [ -e "$a" ]; then FILTERS+=("$a")
  else echo "no such test path: $a" >&2; exit 2; fi
done

FILES=()
if [ ${#FILTERS[@]} -gt 0 ]; then
  for f in "${FILTERS[@]}"; do
    if [ -d "$f" ]; then
      while IFS= read -r -d '' t; do FILES+=("$t"); done < <(find "$f" -name '*.typ' -print0 | sort -z)
    else
      FILES+=("$f")
    fi
  done
else
  while IFS= read -r -d '' t; do FILES+=("$t"); done < <(find tests -name '*.typ' -print0 | sort -z)
fi

pass=0
fail=0
FF="--ignore-system-fonts"
[ "${CAXTON_SYSTEM_FONTS:-0}" = "1" ] && FF=""

for f in "${FILES[@]}"; do
  base="$(basename "$f")"
  # Skip fixtures (this file itself, or anything under a "_"-prefixed dir).
  case "$base" in _*) continue ;; esac
  case "$f" in */_*) continue ;; esac

  read_expect "$f"
  if [ -n "$want" ]; then
    tmp="$OUT/_tmp.$$.pdf"
    out=$(typst compile $FF --root "$ROOT" "$f" "$tmp" 2>&1)
    code=$?
    rm -f "$tmp"
    if [ $code -eq 0 ]; then
      echo "  FAIL $f  (expected an error, but it compiled)"
      fail=$((fail + 1))
    elif ! printf '%s' "$out" | grep -qF "$want"; then
      echo "  FAIL $f  (errored, but message lacked: \"$want\")"
      printf '%s\n' "$out" | sed 's/^/       /'
      fail=$((fail + 1))
    else
      echo "  ok   $f  (errored as expected: \"$want\")"
      pass=$((pass + 1))
    fi
  else
    rel="${f#tests/}"
    dest="$OUT/${rel%.typ}.pdf"
    mkdir -p "$(dirname "$dest")"
    err="$OUT/_err.$$"
    if typst compile $FF --root "$ROOT" "$f" "$dest" >"$err" 2>&1; then
      echo "  ok   $f  -> $dest"
      pass=$((pass + 1))
    else
      echo "  FAIL $f  (expected to compile, but it errored)"
      sed 's/^/       /' "$err"
      fail=$((fail + 1))
    fi
    rm -f "$err"
  fi
done

echo "----------------------------------------"
echo "passed=$pass failed=$fail  ($((pass + fail)) tests)"
[ $fail -eq 0 ]
