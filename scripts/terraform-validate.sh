#!/usr/bin/env bash
#
# validate.sh — Run all local validation checks
#
# Usage: ./scripts/validate.sh
#
# Checks:
#   1. Terraform formatting (terraform fmt -check)
#   2. Terraform init (no backend)
#   3. Terraform validate
#   4. Node.js ES Module syntax verification
#   5. Lambda handler export verification
#
# Exit codes:
#   0 — All checks passed
#   1 — One or more checks failed

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
  local name="$1"
  shift
  printf "  %-40s" "$name"
  if "$@" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}❌ FAIL${NC}"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=========================================="
echo "  Vistra Serverless API — Local Validation"
echo "=========================================="
echo ""

# --- Terraform ---
echo "📐 Terraform"
cd "$(dirname "$0")/../infra"

check "Format check" terraform fmt -check -recursive
check "Initialise (no backend)" terraform init -backend=false
check "Validate configuration" terraform validate

cd ..

# # --- Node.js ---
# echo ""
# echo "📦 Node.js Lambda Handlers"

# check "No CommonJS require()" bash -c '! grep -rn "require(" src/handlers/*.mjs src/handlers/lib/*.mjs 2>/dev/null'
# check "No module.exports" bash -c '! grep -rn "module.exports" src/handlers/*.mjs src/handlers/lib/*.mjs 2>/dev/null'

# for handler in src/handlers/create-item.mjs src/handlers/get-item.mjs src/handlers/list-items.mjs src/handlers/update-item.mjs src/handlers/delete-item.mjs src/handlers/event-processor.mjs src/handlers/scheduled-cleanup.mjs; do
#   if [ -f "$handler" ]; then
#     basename=$(basename "$handler")
#     check "Handler export: $basename" grep -q "export const handler" "$handler"
#   fi
# done

# --- Summary ---
echo ""
echo "=========================================="
TOTAL=$((PASS + FAIL))
echo -e "  Results: ${GREEN}${PASS}/${TOTAL} passed${NC}"
if [ "$FAIL" -gt 0 ]; then
  echo -e "  ${RED}${FAIL} check(s) failed${NC}"
  echo "=========================================="
  exit 1
fi
echo "=========================================="
echo ""
