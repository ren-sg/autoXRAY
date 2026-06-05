#!/bin/bash
# Render nginx configs from service descriptors.

set -euo pipefail

AUTOXRAY_ROOT="${AUTOXRAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=extensions/lib/common.sh
source "$AUTOXRAY_ROOT/extensions/lib/common.sh"

TPL_SSL="$AUTOXRAY_ROOT/extensions/nginx/templates/service-ssl-unix.conf.tpl"
TPL_HTTP="$AUTOXRAY_ROOT/extensions/nginx/templates/service-http80.conf.tpl"

render_websocket_block() {
    if [[ "${SERVICE_WEBSOCKET:-0}" == "1" ]]; then
        cat <<'EOF'
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
EOF
    fi
}

render_service() {
    local service_file="$1"
    # shellcheck source=/dev/null
    source "$service_file"

    : "${SERVICE_NAME:?SERVICE_NAME не задан в $service_file}"
    : "${SERVICE_DOMAIN:?SERVICE_DOMAIN не задан в $service_file}"
    : "${SERVICE_UPSTREAM:?SERVICE_UPSTREAM не задан в $service_file}"

    SERVICE_WEBSOCKET="${SERVICE_WEBSOCKET:-0}"
    export SERVICE_NAME SERVICE_DOMAIN SERVICE_UPSTREAM SERVICE_WEBSOCKET
    export WEBSOCKET_BLOCK
    WEBSOCKET_BLOCK=$(render_websocket_block)

    mkdir -p "$NGINX_CUSTOM_DIR"

    envsubst '${SERVICE_DOMAIN} ${SERVICE_UPSTREAM} ${WEBSOCKET_BLOCK}' \
        < "$TPL_SSL" > "$NGINX_CUSTOM_DIR/10-${SERVICE_NAME}-ssl.conf"

    envsubst '${SERVICE_DOMAIN}' \
        < "$TPL_HTTP" > "$NGINX_CUSTOM_DIR/20-${SERVICE_NAME}-http.conf"

    log_info "Rendered nginx: $SERVICE_NAME ($SERVICE_DOMAIN)"
}

render_all_services() {
    load_env
    mkdir -p "$NGINX_CUSTOM_DIR"

    local f count=0
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        render_service "$f"
        count=$((count + 1))
    done < <(list_service_env_files)

    if [[ $count -eq 0 ]]; then
        log_warn "Нет extensions/services/*.env — только upstream VPN"
    fi
}

case "${1:-all}" in
    all) render_all_services ;;
    *)
        render_service "$1"
        ;;
esac
