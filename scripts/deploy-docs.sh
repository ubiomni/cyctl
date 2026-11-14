#!/usr/bin/env bash
# Build mdBook docs and publish to ubiomni.com + GitHub Pages.
#
# Usage:
#   ./scripts/deploy-docs.sh                # build + deploy to both
#   ./scripts/deploy-docs.sh --build-only   # build without deploying
#   ./scripts/deploy-docs.sh --server-only  # deploy to ubiomni.com only
#   ./scripts/deploy-docs.sh --github-only  # push to GitHub (triggers Pages)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOK_DIR="${PROJECT_ROOT}/book"
SERVER="ubuntu@152.136.150.236"
REMOTE_DIR="/var/www/ubiomni.com/cyctl"

BUILD_ONLY=false
SERVER_ONLY=false
GITHUB_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --build-only)   BUILD_ONLY=true ;;
    --server-only)  SERVER_ONLY=true ;;
    --github-only)  GITHUB_ONLY=true ;;
    --server=*)     SERVER="${arg#--server=}" ;;
  esac
done

if ! command -v mdbook &>/dev/null; then
  echo "ERROR: mdbook not found. Install: cargo install mdbook" >&2
  exit 1
fi

echo "==> Building docs..."
rm -rf "$BOOK_DIR"
mdbook build "$PROJECT_ROOT/docs/site/en" -d "$BOOK_DIR/en"
mdbook build "$PROJECT_ROOT/docs/site/zh" -d "$BOOK_DIR/zh"
cp "$PROJECT_ROOT/docs/site/index.html" "$BOOK_DIR/"

EN_PAGES=$(find "$BOOK_DIR/en" -name '*.html' | wc -l | tr -d ' ')
ZH_PAGES=$(find "$BOOK_DIR/zh" -name '*.html' | wc -l | tr -d ' ')
echo "    en: ${EN_PAGES} pages, zh: ${ZH_PAGES} pages"

if [[ "$BUILD_ONLY" == true ]]; then
  echo "Done (build only). Output: $BOOK_DIR"
  exit 0
fi

if [[ "$GITHUB_ONLY" != true ]]; then
  echo ""
  echo "==> Deploying to $SERVER:$REMOTE_DIR ..."
  rsync -avz --delete "$BOOK_DIR/" "$SERVER:$REMOTE_DIR/"
  echo "    https://ubiomni.com/cyctl/"
fi

if [[ "$SERVER_ONLY" != true ]]; then
  echo ""
  echo "==> Pushing to GitHub (triggers Pages deploy)..."
  cd "$PROJECT_ROOT"

  if [[ -n "$(git status --porcelain docs/)" ]]; then
    git add docs/
    git commit -m "docs: update documentation"
    git push origin main
    echo "    https://ubiomni.github.io/cyctl/"
  else
    echo "    No doc changes to push."
  fi
fi

echo ""
echo "Done!"
