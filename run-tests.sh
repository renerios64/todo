#!/usr/bin/env bash
# run-tests.sh — runs the full test suite in sequence and prints a detailed summary
# Usage: ./run-tests.sh
# Prerequisites for Playwright (E2E) tests: docker compose up

set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

# ── Table layout ───────────────────────────────────────────────────────────────
# Column widths = visual chars between ║ borders
#   Suite  : 2(indent) + 2(emoji) + 1(space) + 39(name) = 44
#   Passed : 8   →  "  NNNN  "
#   Failed : 8   →  "  NNNN  "
#   Total  : 7   →  "  NNNN "
# Row total: 44+8+8+7 = 67 content + 5 borders = 72 chars wide
SC=44; PC=8; FC=8; TC=7

# Repeat character $2 times $1 times
rep() { printf "$1%.0s" $(seq 1 "$2"); }

SEP_SUITE=$(rep ═ $SC)
SEP_NUM=$(rep ═ $PC)
SEP_TOT=$(rep ═ $TC)
SEP_TOP=$(rep ═ $((SC + PC + FC + TC + 3)))  # +3 for the three inner ╦/╩/╬

# Strip ANSI escape codes
strip_ansi() { sed 's/\x1b\[[0-9;]*[mGKHFABCDJsu]//g'; }

# ── Result storage ─────────────────────────────────────────────────────────────
SUITE_NAMES=()
SUITE_PASSED=()
SUITE_FAILED=()
SUITE_TOTAL=()
SUITE_STATUS=()

GRAND_PASSED=0
GRAND_FAILED=0
GRAND_TOTAL=0

# ── run_suite <display name> <parser> <cmd...> ─────────────────────────────────
run_suite() {
  local name="$1"
  local parser="$2"
  shift 2

  local tmpfile
  tmpfile=$(mktemp)

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  set +e
  "$@" 2>&1 | tee "$tmpfile"
  local exit_code=${PIPESTATUS[0]}
  set -e

  local clean
  clean=$(strip_ansi < "$tmpfile")
  rm -f "$tmpfile"

  local passed=0 failed=0

  case "$parser" in
    vitest)
      # "      Tests  8 passed (8)"
      passed=$(echo "$clean" | grep -E "^\s*Tests\s" \
               | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" | tail -1 || true)
      failed=$(echo "$clean" | grep -E "^\s*Tests\s" \
               | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | tail -1 || true)
      ;;
    dotnet)
      # "Passed!  - Failed:     0, Passed:     8, Skipped:     0, Total: ..."
      local summary_line
      summary_line=$(echo "$clean" | grep -E "^Passed!|^Failed!" | tail -1 || true)
      passed=$(echo "$summary_line" | grep -oE "Passed:\s+[0-9]+" | grep -oE "[0-9]+" || true)
      failed=$(echo "$summary_line" | grep -oE "Failed:\s+[0-9]+" | grep -oE "[0-9]+" || true)
      ;;
    playwright)
      # "  6 passed (1.6s)" and/or "  4 failed"
      passed=$(echo "$clean" | grep -E "^\s+[0-9]+ passed" \
               | grep -oE "[0-9]+" | head -1 || true)
      failed=$(echo "$clean" | grep -E "^\s+[0-9]+ failed" \
               | grep -oE "[0-9]+" | head -1 || true)
      ;;
  esac

  passed=${passed:-0}
  failed=${failed:-0}
  local total=$(( passed + failed ))

  local status="ok"
  [ "$exit_code" -ne 0 ] && status="fail"

  SUITE_NAMES+=("$name")
  SUITE_PASSED+=("$passed")
  SUITE_FAILED+=("$failed")
  SUITE_TOTAL+=("$total")
  SUITE_STATUS+=("$status")

  GRAND_PASSED=$(( GRAND_PASSED + passed ))
  GRAND_FAILED=$(( GRAND_FAILED + failed ))
  GRAND_TOTAL=$(( GRAND_TOTAL  + total  ))
}

# ── Run all suites ─────────────────────────────────────────────────────────────

run_suite "React UI tests (Vitest)" vitest \
  npm --prefix "$ROOT/src/web" run test -- --run

run_suite ".NET unit tests (InMemory)" dotnet \
  dotnet test "$ROOT/tests/unit"

run_suite ".NET integration tests (Testcontainers)" dotnet \
  dotnet test "$ROOT/tests/integration"

run_suite "Playwright system tests (E2E)" playwright \
  bash -c "cd '$ROOT/tests/system' && npx playwright test"

# ── Summary table ──────────────────────────────────────────────────────────────
#
# Visual layout (72 chars wide):
#   ╔══════════════════════════════════════════════════════════════════════╗
#   ║                          TEST SUMMARY                               ║
#   ╠════════════════════════════════════════════╦════════╦════════╦═══════╣
#   ║  Suite                                     ║ Passed ║ Failed ║ Total ║
#   ╠════════════════════════════════════════════╬════════╬════════╬═══════╣
#   ║  ✅ Suite name here                        ║     8  ║     0  ║     8 ║
#   ╠════════════════════════════════════════════╬════════╬════════╬═══════╣
#   ║  TOTAL                                     ║    28  ║     0  ║    28 ║
#   ╚════════════════════════════════════════════╩════════╩════════╩═══════╝
#
# Emoji alignment: ✅/❌ are 2 visual columns wide. By using "%s %-39s" we put
# the emoji in an unpadded %s (outputs 2 visual cols) and pad only the name
# to 39 chars. Total suite column: 2(indent)+2(emoji)+1(space)+39(name) = 44. ✓

echo ""
echo "╔${SEP_TOP}╗"
printf "║%*s%s%*s║\n" 29 "" "TEST SUMMARY" 29 ""
echo "╠${SEP_SUITE}╦${SEP_NUM}╦${SEP_NUM}╦${SEP_TOT}╣"
printf "║  Suite%-37s║ Passed ║ Failed ║ Total ║\n" ""
echo "╠${SEP_SUITE}╬${SEP_NUM}╬${SEP_NUM}╬${SEP_TOT}╣"

OVERALL_STATUS=0

for i in "${!SUITE_NAMES[@]}"; do
  name="${SUITE_NAMES[$i]}"
  passed="${SUITE_PASSED[$i]}"
  failed="${SUITE_FAILED[$i]}"
  total="${SUITE_TOTAL[$i]}"
  status="${SUITE_STATUS[$i]}"

  if [ "$status" = "ok" ]; then
    icon="✅"
  else
    icon="❌"
    OVERALL_STATUS=1
  fi

  # %s = emoji (unpadded, 2 visual cols)
  # %-39s = name left-padded to 39 chars (ASCII = 39 visual cols)
  # Together: 2(indent) + 2(emoji) + 1(space) + 39(name) = 44 visual cols ✓
  printf "║  %s %-39s║  %4s  ║  %4s  ║  %4s ║\n" \
    "$icon" "$name" "$passed" "$failed" "$total"
done

echo "╠${SEP_SUITE}╬${SEP_NUM}╬${SEP_NUM}╬${SEP_TOT}╣"
printf "║  TOTAL%-37s║  %4s  ║  %4s  ║  %4s ║\n" \
  "" "$GRAND_PASSED" "$GRAND_FAILED" "$GRAND_TOTAL"
echo "╚${SEP_SUITE}╩${SEP_NUM}╩${SEP_NUM}╩${SEP_TOT}╝"
echo ""

exit $OVERALL_STATUS
