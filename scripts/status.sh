#!/usr/bin/env bash
echo "=== Headburst VPS Status ==="
echo "OS: $(. /etc/os-release 2>/dev/null; echo ${PRETTY_NAME:-unknown})"
echo "Panel dir: $(test -d /var/www/pterodactyl && echo YES || echo NO)"
echo "Wings bin: $(test -x /usr/local/bin/wings && echo YES || echo NO)"
echo "Wings svc: $(systemctl is-active wings 2>/dev/null || echo n/a)"
echo "Nginx: $(systemctl is-active nginx 2>/dev/null || echo n/a)"
echo "Docker: $(systemctl is-active docker 2>/dev/null || echo n/a)"
echo "Blueprint: $(test -f /var/www/pterodactyl/blueprint.sh && echo YES || echo NO)"
df -h / | tail -1
free -h | head -2
