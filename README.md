# Headburst VPS Panel

Custom-designed control panel to install and manage:

- **Pterodactyl Panel**
- **Wings** daemon
- **Blueprint** framework
- **Themes** (from a ZIP URL)

![Node](https://img.shields.io/badge/node-%3E%3D18-brightgreen)

## Quick start (on your VPS)

```bash
git clone https://github.com/RaghavGaming000/headburst-vps-panel.git
cd headburst-vps-panel
npm install
sudo npm start
```

Open: **http://YOUR_VPS_IP:3080**

Default panel password: `headburst@vps`  
Change with:

```bash
PANEL_PASS='your-strong-password' sudo -E npm start
```

## Features

| Action | What it does |
|--------|----------------|
| Install Panel | PHP 8.3, Nginx, MariaDB, Redis, Panel, queue, optional SSL |
| Install Wings | Docker + Wings binary + systemd unit |
| Install Blueprint | Blueprint framework on existing panel |
| Apply Theme | Download theme ZIP URL and apply / Blueprint install |

## Scripts (CLI)

```bash
sudo bash scripts/install-panel.sh panel.example.com admin@example.com admin 'YourPass'
sudo bash scripts/install-wings.sh
sudo bash scripts/install-blueprint.sh
sudo bash scripts/install-theme.sh https://example.com/theme.zip nebula
bash scripts/status.sh
```

## Security

- Run only on trusted networks or behind a firewall
- Change `PANEL_PASS` before production use
- Install scripts require **root** (they install system packages)

## License

MIT — use at your own risk on machines you own.
