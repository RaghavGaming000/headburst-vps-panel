#!/usr/bin/env bash
#
# Headburst Pterodactyl Installer
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/RaghavGaming000/headburst-vps-panel/main/install.sh)
#
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*" >&2; }
die()   { err "$*"; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo bash <(curl -fsSL ...)"

clear 2>/dev/null || true
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
 _   _                _ _                    _
| | | | ___  __ _  __| | |__  _   _ _ __ ___| |_
| |_| |/ _ \/ _` |/ _` | '_ \| | | | '__/ __| __|
|  _  |  __/ (_| | (_| | |_) | |_| | |  \__ \ |_
|_| |_|\___|\__,_|\__,_|_.__/ \__,_|_|  |___/\__|
          Pterodactyl Installer
BANNER
echo -e "${NC}"

if [[ -f /etc/os-release ]]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_VER="${VERSION_ID:-}"
else
  die "Cannot detect OS"
fi

info "OS: ${PRETTY_NAME:-$OS_ID $OS_VER}"
[[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]] || warn "Script targets Ubuntu/Debian. Continuing anyway..."

export DEBIAN_FRONTEND=noninteractive

menu() {
  echo ""
  echo -e "${BOLD}What do you want to install?${NC}"
  echo "  1) Pterodactyl Panel"
  echo "  2) Wings (node daemon)"
  echo "  3) Panel + Wings (same machine)"
  echo "  4) Blueprint framework (panel required)"
  echo "  5) Status check"
  echo "  6) Uninstall Panel + Wings (wipe)"
  echo "  0) Exit"
  echo ""
  read -r -p "Select [0-6]: " CHOICE
}

ask() {
  local prompt="$1" default="${2:-}"
  local value
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " value
    echo "${value:-$default}"
  else
    read -r -p "$prompt: " value
    echo "$value"
  fi
}

install_deps_base() {
  info "Updating packages..."
  apt-get update -qq
  apt-get -y install curl ca-certificates apt-transport-https software-properties-common \
    tar unzip git gnupg > /dev/null
}

install_panel() {
  local DOMAIN EMAIL ADMIN_USER ADMIN_PASS
  DOMAIN=$(ask "Panel domain (e.g. panel.example.com)")
  EMAIL=$(ask "Admin email" "admin@${DOMAIN}")
  ADMIN_USER=$(ask "Admin username" "admin")
  ADMIN_PASS=$(ask "Admin password" "admin@434")
  [[ -n "$DOMAIN" ]] || die "Domain required"

  install_deps_base
  info "Installing PHP / Nginx / MariaDB / Redis..."
  add-apt-repository -y ppa:ondrej/php >/dev/null 2>&1 || true
  apt-get update -qq
  apt-get -y install php8.3 php8.3-{cli,common,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} \
    nginx mariadb-server redis-server

  if ! command -v composer >/dev/null; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  fi

  local DB_PASS
  DB_PASS=$(openssl rand -base64 18 | tr -d '=+/')
  mysql -e "CREATE DATABASE IF NOT EXISTS panel;"
  mysql -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
  mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;"
  echo "$DB_PASS" > /root/.ptero_db_pass
  chmod 600 /root/.ptero_db_pass

  info "Downloading Panel..."
  mkdir -p /var/www/pterodactyl
  cd /var/www/pterodactyl
  curl -fsSL -o panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
  tar -xzf panel.tar.gz
  chmod -R 755 storage/* bootstrap/cache/
  cp -n .env.example .env 2>/dev/null || cp .env.example .env
  export COMPOSER_ALLOW_SUPERUSER=1
  composer install --no-dev --optimize-autoloader -q
  php artisan key:generate --force

  sed -i "s|^APP_URL=.*|APP_URL=https://${DOMAIN}|" .env
  sed -i "s|^APP_TIMEZONE=.*|APP_TIMEZONE=UTC|" .env
  sed -i "s|^CACHE_DRIVER=.*|CACHE_DRIVER=redis|" .env
  sed -i "s|^SESSION_DRIVER=.*|SESSION_DRIVER=redis|" .env
  sed -i "s|^QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|" .env
  sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" .env
  sed -i "s|^DB_DATABASE=.*|DB_DATABASE=panel|" .env
  sed -i "s|^DB_USERNAME=.*|DB_USERNAME=pterodactyl|" .env
  sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env

  php artisan migrate --seed --force
  php artisan p:user:make --email="$EMAIL" --username="$ADMIN_USER" \
    --name-first=Admin --name-last=User --password="$ADMIN_PASS" --admin=1 || true
  chown -R www-data:www-data /var/www/pterodactyl

  cat > /etc/nginx/sites-available/pterodactyl.conf << NGX
server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/pterodactyl/public;
    index index.php;
    client_max_body_size 100m;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
NGX
  ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl restart nginx php8.3-fpm

  cat > /etc/systemd/system/pteroq.service << 'SVC'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
SVC
  systemctl enable --now redis-server pteroq

  (crontab -l 2>/dev/null | grep -v pterodactyl; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

  apt-get -y install certbot python3-certbot-nginx >/dev/null 2>&1 || true
  if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect 2>/dev/null; then
    ok "SSL enabled for https://${DOMAIN}"
  else
    warn "SSL skipped — point DNS A record to this server, then run:"
    echo "  certbot --nginx -d ${DOMAIN}"
  fi

  ok "Panel installed"
  echo "  URL:  http(s)://${DOMAIN}"
  echo "  User: ${ADMIN_USER}"
  echo "  Pass: ${ADMIN_PASS}"
}

install_wings() {
  install_deps_base
  if ! command -v docker >/dev/null; then
    info "Installing Docker..."
    curl -fsSL https://get.docker.com | CHANNEL=stable bash
  fi
  systemctl enable --now docker

  mkdir -p /etc/pterodactyl /var/lib/pterodactyl/volumes
  local ARCH BIN
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64) BIN=wings_linux_amd64 ;;
    aarch64|arm64) BIN=wings_linux_arm64 ;;
    *) die "Unsupported arch: $ARCH" ;;
  esac

  info "Downloading Wings..."
  curl -fsSL -o /usr/local/bin/wings \
    "https://github.com/pterodactyl/wings/releases/latest/download/${BIN}"
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

  if [[ -f /etc/pterodactyl/config.yml ]]; then
    systemctl restart wings
    ok "Wings running"
    systemctl --no-pager -l status wings | head -12
  else
    ok "Wings binary installed"
    echo "  1. Create a node in the Panel"
    echo "  2. Copy Configuration YAML → /etc/pterodactyl/config.yml"
    echo "  3. systemctl start wings"
  fi
}

install_blueprint() {
  [[ -d /var/www/pterodactyl ]] || die "Install Panel first"
  cd /var/www/pterodactyl
  export COMPOSER_ALLOW_SUPERUSER=1
  if [[ ! -f blueprint.sh ]]; then
    curl -fsSL -o blueprint.sh \
      https://github.com/BlueprintFramework/framework/releases/latest/download/blueprint.sh
    chmod +x blueprint.sh
  fi
  bash blueprint.sh -y 2>/dev/null || bash blueprint.sh || true
  chown -R www-data:www-data /var/www/pterodactyl
  ok "Blueprint installed (or already present)"
}

status_check() {
  echo "Panel dir : $([[ -d /var/www/pterodactyl ]] && echo YES || echo NO)"
  echo "Wings bin : $([[ -x /usr/local/bin/wings ]] && echo YES || echo NO)"
  echo "Wings svc : $(systemctl is-active wings 2>/dev/null || echo n/a)"
  echo "Nginx     : $(systemctl is-active nginx 2>/dev/null || echo n/a)"
  echo "Docker    : $(systemctl is-active docker 2>/dev/null || echo n/a)"
  echo "pteroq    : $(systemctl is-active pteroq 2>/dev/null || echo n/a)"
  df -h / | tail -1
}

uninstall_all() {
  warn "This removes Panel, Wings, and game data."
  read -r -p "Type YES to confirm: " c
  [[ "$c" == "YES" ]] || die "Cancelled"
  systemctl stop wings pteroq 2>/dev/null || true
  systemctl disable wings pteroq 2>/dev/null || true
  docker stop $(docker ps -aq) 2>/dev/null || true
  docker rm $(docker ps -aq) 2>/dev/null || true
  rm -f /usr/local/bin/wings
  rm -rf /etc/pterodactyl /var/www/pterodactyl /var/lib/pterodactyl /var/log/pterodactyl
  rm -f /etc/systemd/system/wings.service /etc/systemd/system/pteroq.service
  rm -f /etc/nginx/sites-enabled/pterodactyl.conf /etc/nginx/sites-available/pterodactyl.conf
  systemctl daemon-reload
  mysql -e "DROP DATABASE IF EXISTS panel; DROP USER IF EXISTS 'pterodactyl'@'127.0.0.1'; FLUSH PRIVILEGES;" 2>/dev/null || true
  docker system prune -af 2>/dev/null || true
  ok "Removed"
}

menu
case "${CHOICE:-0}" in
  1) install_panel ;;
  2) install_wings ;;
  3) install_panel; install_wings ;;
  4) install_blueprint ;;
  5) status_check ;;
  6) uninstall_all ;;
  0) exit 0 ;;
  *) die "Invalid option" ;;
esac

echo ""
ok "Done."
