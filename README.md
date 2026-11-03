# Headburst VPS Panel v2

Custom dark/light control panel for your VPS:

- Install **Pterodactyl Panel**, **Wings**, **Blueprint**, **themes**
- **Root console** (WebSocket shell + quick command exec)
- **File browser** (list, open, edit, save)
- **VPS password vault** (view / change **your** saved VPS passwords only — AES encrypted)

## Quick start

```bash
git clone https://github.com/RaghavGaming000/headburst-vps-panel.git
cd headburst-vps-panel
npm install
sudo npm start
```

Open **http://YOUR_IP:3080**  
Default login: `headburst@vps`

```bash
PANEL_PASS='strong-password' sudo -E npm start
```

## Features

| Tab | What you get |
|-----|----------------|
| Home | Host stats + system status script |
| Install | Panel, Wings, Blueprint, Theme ZIP |
| Console | Interactive shell + Run command |
| Files | Browse / open / edit files |
| Passwords | Add, view, change, delete **your** VPS passwords |

Theme toggle (dark / light) is in the header.

## Tests

```bash
npm test
```

## Security

- Change `PANEL_PASS` before public use
- Firewall port 3080 to trusted IPs
- Password vault is encrypted with your panel login
- Console runs as the user that starts Node (use `sudo` for root)

## License

MIT
