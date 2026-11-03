# Headburst Pterodactyl Installer

One-line installer (same style as `bash <(curl -s https://ptero.jishnu.site)`):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RaghavGaming000/headburst-vps-panel/main/install.sh)
```

Or:

```bash
curl -fsSL https://raw.githubusercontent.com/RaghavGaming000/headburst-vps-panel/main/install.sh | bash
```

## Menu

1. **Pterodactyl Panel** — Nginx, PHP 8.3, MariaDB, Redis, SSL  
2. **Wings** — Docker + daemon  
3. **Panel + Wings** — both on one machine  
4. **Blueprint** — theme/extension framework  
5. **Status check**  
6. **Uninstall** — wipe panel/wings/data  

## Requirements

- Ubuntu 22.04+ (or Debian)  
- Root (`sudo`)  
- For SSL: domain DNS A record pointing to the VPS  

## After Wings install

1. Create a **node** in the Panel  
2. Copy **Configuration** YAML → `/etc/pterodactyl/config.yml`  
3. `systemctl start wings`  

## License

MIT
