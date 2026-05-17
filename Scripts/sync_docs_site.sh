#!/usr/bin/env bash
# Sync marketing site from DesignSystem into docs/ for GitHub Pages.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DS="${REPO_ROOT}/DesignSystem/project"
DOCS="${REPO_ROOT}/docs"

if [[ ! -d "$DS/marketing" ]]; then
  echo "error: DesignSystem/project/marketing not found (export design bundle first)" >&2
  exit 1
fi

mkdir -p "${DOCS}/assets/screenshots"
cp "${DS}/marketing/marketing.css" "${DOCS}/"
cp "${DS}/colors_and_type.css" "${DS}/cartoon.css" "${DOCS}/"
cp -R "${DS}/assets/"* "${DOCS}/assets/"
cp "${DS}/marketing/assets/screenshots/"*.png "${DOCS}/assets/screenshots/"
cp "${DS}/marketing/index.html" "${DOCS}/index.html"

sed -i '' \
  -e 's|../assets/|assets/|g' \
  -e 's|../colors_and_type.css|colors_and_type.css|g' \
  -e 's|../cartoon.css|cartoon.css|g' \
  "${DOCS}/index.html"

touch "${DOCS}/.nojekyll"
echo "Synced marketing site → docs/"
