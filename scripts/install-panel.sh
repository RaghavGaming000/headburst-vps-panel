#!/usr/bin/env bash
# Install Pterodactyl Panel (Ubuntu 22.04 recommended)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
DOMAIN="${1:-panel.example.com}"
EMAIL="${2:-admin@example.com}"
ADMIN_USER="${3:-admin}"
ADMIN_PASS="${4:-ChangeMe123!}"

if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi

apt-get update -qq
apt-get -y install software-properties-common curl apt-transport-https ca-certificates gnupg tar unzip git

add-apt-repository -y ppa:ondrej/php >/dev/null 2>&1 || true
apt-get update -qq
apt-get -y install php8.3 php8.3-{cli,common,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl,redis} \
  nginx mariadb-server redis-server

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

DB_PASS=$(openssl rand -base64 18 | tr -d '=+/')
mysql -e "CREATE DATABASE IF NOT EXISTS panel;"
mysql -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;"
echo "$DB_PASS" > /root/.ptero_db_pass
chmod 600 /root/.ptero_db_pass

mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/
cp .env.example .env
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
php artisan p:user:make --email="$EMAIL" --username="$ADMIN_USER" --name-first=Admin --name-last=User --password="$ADMIN_PASS" --admin=1 || true
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
nginx -t && systemctl restart nginx php8.3-fpm

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
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect 2>/dev/null || echo "SSL skipped (DNS must point here first)"

echo "PANEL_INSTALLED domain=${DOMAIN} user=${ADMIN_USER}"
