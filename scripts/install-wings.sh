#!/usr/bin/env bash
# Install Pterodactyl Wings daemon
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi

if ! command -v docker >/dev/null; then
  curl -sSL https://get.docker.com/ | CHANNEL=stable bash
fi
systemctl enable --now docker

mkdir -p /etc/pterodactyl /var/lib/pterodactyl/volumes
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) BIN=wings_linux_amd64 ;;
  aarch64|arm64) BIN=wings_linux_arm64 ;;
  *) echo "Unsupported arch $ARCH"; exit 1 ;;
esac

curl -fsSL -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/${BIN}"
chmod +x /usr/local/bin/wings

cat > /etc/systemd/system/wings.service << 'SVC'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service
[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
ExecStart=/usr/local/bin/wings
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
SVC
systemctl daemon-reload
systemctl enable wings

echo "WINGS_INSTALLED"
echo "Next: create a node in the Panel, copy Configuration YAML to /etc/pterodactyl/config.yml"
echo "Then: systemctl start wings"
if [[ -f /etc/pterodactyl/config.yml ]]; then
  systemctl restart wings
  systemctl --no-pager -l status wings | head -15
else
  echo "No config.yml yet — Wings not started."
fi
