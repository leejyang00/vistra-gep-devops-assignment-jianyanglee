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

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HANDLERS_DIR="$REPO_ROOT/src/handlers"
DIST_DIR="$REPO_ROOT/dist/handlers"

HANDLERS=(
  create-item
  get-item
  list-items
  update-item
  delete-item
  event-processor
  scheduled-cleanup
)

echo ""
echo "=========================================="
echo "  Vistra Serverless API — Local Validation"
echo "=========================================="
echo ""

echo ""
echo "📦 Node.js Lambda Handlers — Conventions"

check "No CommonJS require()" bash -c '! grep -rn "require(" '"$HANDLERS_DIR"'/*.mjs '"$HANDLERS_DIR"'/utils/*.mjs 2>/dev/null'
check "No module.exports" bash -c '! grep -rn "module.exports" '"$HANDLERS_DIR"'/*.mjs '"$HANDLERS_DIR"'/utils/*.mjs 2>/dev/null'

for name in "${HANDLERS[@]}"; do
  handler="$HANDLERS_DIR/$name.mjs"
  if [ -f "$handler" ]; then
    check "Handler export: $name.mjs" grep -q "export const handler" "$handler"
  fi
done

echo ""
echo "📥 Dependency Install"

check "npm ci (src/handlers)" npm ci --prefix "$HANDLERS_DIR" --silent

echo ""
echo "🔎 Node 22 Syntax Check"

for f in "$HANDLERS_DIR"/*.mjs "$HANDLERS_DIR"/utils/*.mjs; do
  [ -f "$f" ] || continue
  rel="${f#$REPO_ROOT/}"
  check "node --check $rel" node --check "$f"
done

echo ""
echo "🧹 Biome Lint / Format"

check "biome check (src/handlers)" \
  bash -c "cd '$HANDLERS_DIR' && npx --no-install biome check ."

echo ""
echo "📦 Build & Package (zip per handler)"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

UTILS_FILES=(
  utils/logger.mjs
  utils/response.mjs
  utils/validator.mjs
  utils/dynamodb.mjs
)

package_handler() {
  local name="$1"
  local handler="$HANDLERS_DIR/$name.mjs"
  [ -f "$handler" ] || return 1
  local out="$DIST_DIR/$name.zip"
  rm -f "$out"
  ( cd "$HANDLERS_DIR" && zip -q "$out" "$name.mjs" "${UTILS_FILES[@]}" )
}

for name in "${HANDLERS[@]}"; do
  if [ -f "$HANDLERS_DIR/$name.mjs" ]; then
    check "package $name.zip" package_handler "$name"
  fi
done

if [ -d "$DIST_DIR" ] && compgen -G "$DIST_DIR/*.zip" > /dev/null; then
  echo ""
  echo "  Artifacts (dist/handlers/):"
  ( cd "$DIST_DIR" && ls -lh *.zip | awk '{ printf "    %-30s %s\n", $NF, $5 }' )
fi

echo ""
echo "=========================================="
echo "  Summary: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "=========================================="
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
