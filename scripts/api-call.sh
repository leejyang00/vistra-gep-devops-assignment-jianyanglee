#!/usr/bin/env bash
set -euo pipefail

# Resolve paths relative to this script so it works from any cwd
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"

if [[ ! -d "$INFRA_DIR" ]]; then
  echo "Error: infra directory not found at $INFRA_DIR" >&2
  exit 1
fi

API_URL=$(terraform -chdir="$INFRA_DIR" output -raw api_endpoint 2>/dev/null || true)
if [[ -z "${API_URL:-}" ]]; then
  echo "Error: terraform output 'api_endpoint' is empty. Run 'terraform apply' first." >&2
  exit 1
fi

echo "Testing API: $API_URL"
echo

read -r -p "Enter item ID: " ITEM_ID
# if [[ -z "$ITEM_ID" ]]; then
#   echo "Error: item ID is required" >&2
#   exit 1
# fi
echo

TMP_BODY=$(mktemp)
trap 'rm -f "$TMP_BODY"' EXIT

# call <method> <path> [body]
# Emits one TSV row: METHOD <TAB> PATH <TAB> STATUS <TAB> RESPONSE
call() {
  local method="$1" path="$2" body="${3:-}"
  local -a args=(-sS -o "$TMP_BODY" -w "%{http_code}" -X "$method" "$API_URL$path")
  [[ -n "$body" ]] && args+=(-H "Content-Type: application/json" -d "$body")

  local status resp
  status=$(curl "${args[@]}" || echo "ERR")
  resp=$(tr -d '\n\t' < "$TMP_BODY")

  printf '%s\t%s\t%s\t%s\n' "$method" "$path" "$status" "${resp:--}"
}

{
  printf 'METHOD\tPATH\tSTATUS\tRESPONSE\n'
  call GET    "/items"
  call POST   "/items"            "$(printf '{"id":"%s","name":"test"}' "$ITEM_ID")"
  call GET    "/items/$ITEM_ID"
  call PUT    "/items/$ITEM_ID"   '{"name":"updated"}'
  call DELETE "/items/$ITEM_ID"
  call GET    "/items/$ITEM_ID"
} | column -t -s "$(printf '\t')"
