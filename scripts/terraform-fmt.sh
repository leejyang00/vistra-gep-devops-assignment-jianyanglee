#!/usr/bin/env bash
#
# terraform-fmt.sh — Auto-fix Terraform formatting under infra/
#
# Usage: ./scripts/terraform-fmt.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"

if [[ ! -d "$INFRA_DIR" ]]; then
  echo "Error: infra directory not found at $INFRA_DIR" >&2
  exit 1
fi

echo "Formatting Terraform files under: $INFRA_DIR"
echo

# -recursive: descend into modules
# -diff:      show what changed
# -write=true (default): apply the fixes
CHANGED=$(terraform -chdir="$INFRA_DIR" fmt -recursive -diff)

if [[ -z "$CHANGED" ]]; then
  echo "All files already formatted."
else
  echo "Reformatted:"
  echo "$CHANGED" | sed 's/^/  /'
fi
