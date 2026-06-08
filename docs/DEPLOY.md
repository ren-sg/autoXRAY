# Deploy autoXRAY + extensions on Ubuntu 24.04

## Prerequisites

- Clean Ubuntu 24.04 VDS, root or sudo
- DNS A-records pointing to VPS IP:
  - VPN subdomain → VPS (value of `XRAY_DOMAIN` in `.env`)
  - Each app subdomain → VPS (value of `SERVICE_DOMAIN` in service env files)
- Firewall: SSH, **80**, **443**, **8443**, **10443**; **2408** if WARP enabled

## First-time setup

```bash
ssh root@YOUR_VDS_IP

# Bootstrap (git not installed on minimal image)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/.../scripts/bootstrap.sh)"
# or from cloned repo:
# ./scripts/bootstrap.sh

git clone --recurse-submodules <repo-url> /opt/autoxray
cd /opt/autoxray

# если клонировали без --recurse-submodules:
# git submodule update --init --recursive

cp .env.example .env
nano .env

cp extensions/services/example.env.example extensions/services/myapp.env
nano extensions/services/myapp.env

chmod +x install.sh extensions/*.sh extensions/lib/*.sh scripts/*.sh
./install.sh
```

## `.env` (on server only, not in git)

```env
XRAY_DOMAIN=vpn.example.com
CERTBOT_EMAIL=you@example.com
USE_WARP=1
NGINX_CUSTOM_DIR=/etc/nginx/conf.d/autoxray-custom
STATE_DIR=/etc/autoXRAY
```

## Service descriptor (on server only)

```bash
cp extensions/services/example.env.example extensions/services/myapp.env
```

```env
SERVICE_NAME=myapp
SERVICE_DOMAIN=app.example.com
SERVICE_UPSTREAM=http://127.0.0.1:8080
SERVICE_WEBSOCKET=0
```

For WebSocket apps set `SERVICE_WEBSOCKET=1`.

## Docker upstream (manual, separate git)

Bind only localhost — **do not** use host port 443 (Xray owns it):

```yaml
services:
  myapp:
    ports:
      - "127.0.0.1:8080:8080"
```

Start after `./install.sh`. Until upstream runs, HTTPS returns 502.

## Update after git push

Подробнее об обновлении submodule: [VENDOR.md](VENDOR.md).

```bash
cd /opt/autoxray
git pull --recurse-submodules
git submodule update --init --recursive
# опционально: обновить upstream до последнего main
# git submodule update --remote vendor/autoXRAY
./install.sh
```

`.env` and `extensions/services/*.env` are not overwritten by `git pull`.

**Warning:** re-running `./install.sh` regenerates VPN keys and subscription paths (upstream behavior). Client configs must be updated. Stable subscription URL: `https://$XRAY_DOMAIN/subscription.json` (symlink recreated each run).

## Architecture

External HTTPS on port 443:

1. **VPN clients** → Xray REALITY on `$XRAY_DOMAIN`
2. **Browsers** → Xray fallback → nginx (unix socket) → static site or `proxy_pass` to Docker

Custom nginx configs live in `$NGINX_CUSTOM_DIR` (default `/etc/nginx/conf.d/autoxray-custom/`). Upstream only overwrites its own default site file.

## Verification

```bash
nginx -t
ss -tlnp | grep -E ':443|:40000'
curl -I "https://$XRAY_DOMAIN"
curl -I "https://app.example.com"   # after docker is up
systemctl status nginx xray
ls /etc/nginx/conf.d/autoxray-custom/
cat /etc/autoXRAY/state.env
```

## WARP

- `USE_WARP=1` — default upstream behavior (WARP-cli SOCKS on :40000)
- `USE_WARP=0` — post-install patches Xray routing `warp` → `direct`

## Certificates

Let's Encrypt, 90 days, auto-renew via `certbot.timer`. See [CERTIFICATES.md](CERTIFICATES.md).

## Troubleshooting

| Issue | Check |
|-------|--------|
| certbot fails | DNS, port 80 open, `/.well-known` on nginx :80; [CERTIFICATES.md](CERTIFICATES.md) |
| 502 on app subdomain | Docker listening on `SERVICE_UPSTREAM` host:port |
| VPN broken after re-run | Update client with new keys / subscription URL |
| WARP not listening | [vendor/autoXRAY/test/warp-readme.md](../vendor/autoXRAY/test/warp-readme.md) |

## SSH deploy from Cursor

Do not commit SSH keys or `.env` to git. After push, connect with key in `authorized_keys`, bootstrap, clone, create `.env` and service files on server, run `./install.sh`.
