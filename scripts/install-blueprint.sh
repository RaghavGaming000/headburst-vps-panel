#!/usr/bin/env bash
# Install Blueprint framework for Pterodactyl (extensions / themes)
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi
PANEL_DIR="${PANEL_DIR:-/var/www/pterodactyl}"
if [[ ! -d "$PANEL_DIR" ]]; then
  echo "Panel not found at $PANEL_DIR — install Panel first."
  exit 1
fi

cd "$PANEL_DIR"
export COMPOSER_ALLOW_SUPERUSER=1

if [[ ! -f blueprint.sh ]]; then
  curl -Lo blueprint.sh https://github.com/BlueprintFramework/framework/releases/latest/download/blueprint.sh
  chmod +x blueprint.sh
fi

bash blueprint.sh -y 2>/dev/null || bash blueprint.sh || true

chown -R www-data:www-data "$PANEL_DIR"
echo "BLUEPRINT_INSTALLED"
echo "Use: blueprint -install <extension>  or place themes under the panel and run blueprint commands."
