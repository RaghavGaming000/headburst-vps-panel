#!/usr/bin/env bash
# Download & apply a Pterodactyl theme (custom zip URL)
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi
PANEL_DIR="${PANEL_DIR:-/var/www/pterodactyl}"
THEME_URL="${1:-}"
THEME_NAME="${2:-custom-theme}"

if [[ ! -d "$PANEL_DIR" ]]; then
  echo "Panel not found at $PANEL_DIR"
  exit 1
fi

if [[ -z "$THEME_URL" ]]; then
  echo "Usage: $0 <theme_zip_url> [theme_name]"
  exit 1
fi

TMP=$(mktemp -d)
cd "$TMP"
curl -L -o theme.zip "$THEME_URL"
unzip -o theme.zip -d theme
if [[ -d theme/public ]]; then
  cp -a theme/public/. "$PANEL_DIR/public/"
fi
if [[ -d theme/resources ]]; then
  cp -a theme/resources/. "$PANEL_DIR/resources/" 2>/dev/null || true
fi
if [[ -f theme/theme.yml ]] || [[ -f theme/blueprint.yml ]]; then
  mkdir -p /var/www/pterodactyl/.blueprint/extensions
  cp -a theme "/var/www/pterodactyl/.blueprint/extensions/${THEME_NAME}"
  if command -v blueprint >/dev/null; then
    cd "$PANEL_DIR" && blueprint -install "$THEME_NAME" || true
  fi
fi

chown -R www-data:www-data "$PANEL_DIR"
cd / && rm -rf "$TMP"
php "$PANEL_DIR/artisan" view:clear 2>/dev/null || true
php "$PANEL_DIR/artisan" cache:clear 2>/dev/null || true
echo "THEME_APPLIED name=${THEME_NAME}"
