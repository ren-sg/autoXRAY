#!/bin/bash
# Save/read state after upstream autoXRAY1.sh runs.

set -euo pipefail

AUTOXRAY_ROOT="${AUTOXRAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=extensions/lib/common.sh
source "$AUTOXRAY_ROOT/extensions/lib/common.sh"

state_save() {
    load_env
    mkdir -p "$STATE_DIR"

    local nginx_cfg path_xhttp path_subpage web_path
    nginx_cfg=$(nginx_config_path)

    path_xhttp=$(grep -oP 'location /\K[a-z0-9]+(?=\s*\{' "$nginx_cfg" 2>/dev/null | head -1 || true)
    path_subpage=$(grep -oP 'location = /\K[A-Za-z0-9]+\.json' "$nginx_cfg" 2>/dev/null | head -1 | sed 's/\.json$//' || true)

    web_path="/var/www/$XRAY_DOMAIN"

    cat > "$STATE_DIR/state.env" <<EOF
XRAY_DOMAIN=$XRAY_DOMAIN
PATH_XHTTP=$path_xhttp
PATH_SUBPAGE=$path_subpage
WEB_PATH=$web_path
NGINX_CUSTOM_DIR=$NGINX_CUSTOM_DIR
STATE_DIR=$STATE_DIR
EOF

    if [[ -n "$path_subpage" && -d "$web_path" ]]; then
        ln -sf "$web_path/$path_subpage.json" "$web_path/subscription.json"
        log_info "Symlink: $web_path/subscription.json → $path_subpage.json"
    fi

    log_info "State saved: $STATE_DIR/state.env"
}

state_load() {
    if [[ -f "${STATE_DIR:-/etc/autoXRAY}/state.env" ]]; then
        # shellcheck source=/dev/null
        source "${STATE_DIR:-/etc/autoXRAY}/state.env"
    fi
}

case "${1:-}" in
    save) state_save ;;
    load) state_load ;;
    *) echo "Usage: $0 save|load" >&2; exit 1 ;;
esac
