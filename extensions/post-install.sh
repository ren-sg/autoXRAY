#!/bin/bash
# Post-install: certs, nginx extensions, optional WARP patch.

set -euo pipefail

AUTOXRAY_ROOT="${AUTOXRAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=extensions/lib/common.sh
source "$AUTOXRAY_ROOT/extensions/lib/common.sh"

ensure_certbot_renewal_hooks() {
    local hook_dir="/etc/letsencrypt/renewal-hooks/deploy"
    local hook="$hook_dir/autoxray-reload-nginx.sh"
    mkdir -p "$hook_dir"
    cat > "$hook" <<'EOF'
#!/bin/bash
# autoXRAY extensions — reload nginx after any cert renewal
systemctl reload nginx
EOF
    chmod +x "$hook"
    log_info "Certbot renewal hook: $hook"
}

ensure_cert() {
    local domain="$1"
    if [[ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]]; then
        log_info "Cert exists: $domain"
        return 0
    fi

    log_info "Issuing cert: $domain"
    certbot certonly --webroot -w /var/www/html \
        -d "$domain" \
        -m "$CERTBOT_EMAIL" \
        --agree-tos --non-interactive \
        --deploy-hook "systemctl reload nginx"
}

issue_service_certs() {
    local f
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        # shellcheck source=/dev/null
        source "$f"
        [[ -n "${SERVICE_DOMAIN:-}" ]] || continue
        ensure_cert "$SERVICE_DOMAIN"
    done < <(list_service_env_files)
}

patch_warp_off() {
    local config="/usr/local/etc/xray/config.json"
    [[ -f "$config" ]] || { log_warn "Xray config not found, skip WARP patch"; return; }

    if ! command -v jq >/dev/null 2>&1; then
        log_warn "jq not found, skip WARP patch"
        return
    fi

    local tmp
    tmp=$(mktemp)
    jq '(.routing.rules[] | select(.outboundTag == "warp") | .outboundTag) |= "direct"' \
        "$config" > "$tmp"
    mv "$tmp" "$config"
    systemctl restart xray
    log_info "WARP routing patched: warp → direct"
}

apply_websocket_directives() {
    local conf="$1"
    local ws="$2"
    if [[ "$ws" == "1" ]]; then
        sed -i '/# WEBSOCKET_DIRECTIVES/c\
        proxy_set_header Upgrade $http_upgrade;\
        proxy_set_header Connection "upgrade";\
        proxy_read_timeout 86400;' "$conf"
    else
        sed -i '/# WEBSOCKET_DIRECTIVES/d' "$conf"
    fi
}

render_all_with_websocket() {
    load_env
    mkdir -p "$NGINX_CUSTOM_DIR"

    local f
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        # shellcheck source=/dev/null
        source "$f"
        : "${SERVICE_NAME:?}"
        : "${SERVICE_DOMAIN:?}"
        : "${SERVICE_UPSTREAM:?}"
        SERVICE_WEBSOCKET="${SERVICE_WEBSOCKET:-0}"
        export SERVICE_DOMAIN SERVICE_UPSTREAM

        local ssl_out="$NGINX_CUSTOM_DIR/10-${SERVICE_NAME}-ssl.conf"
        local http_out="$NGINX_CUSTOM_DIR/20-${SERVICE_NAME}-http.conf"

        envsubst '${SERVICE_DOMAIN} ${SERVICE_UPSTREAM}' \
            < "$AUTOXRAY_ROOT/extensions/nginx/templates/service-ssl-unix.conf.tpl" > "$ssl_out"
        apply_websocket_directives "$ssl_out" "$SERVICE_WEBSOCKET"

        envsubst '${SERVICE_DOMAIN}' \
            < "$AUTOXRAY_ROOT/extensions/nginx/templates/service-http80.conf.tpl" > "$http_out"

        log_info "Rendered nginx: $SERVICE_NAME ($SERVICE_DOMAIN)"
    done < <(list_service_env_files)
}

ensure_nginx_include() {
    local include_snippet="/etc/nginx/conf.d/autoxray-custom-include.conf"
    if [[ ! -f "$include_snippet" ]]; then
        cat > "$include_snippet" <<EOF
# autoXRAY extensions — do not remove
include ${NGINX_CUSTOM_DIR}/*.conf;
EOF
        log_info "Created nginx include: $include_snippet"
    fi
}

main() {
    require_root
    load_env

    mkdir -p "$NGINX_CUSTOM_DIR"
    ensure_nginx_include
    ensure_certbot_renewal_hooks

    issue_service_certs
    render_all_with_websocket

    if [[ "$USE_WARP" == "0" ]]; then
        patch_warp_off
    fi

    if [[ -d "$NGINX_CUSTOM_DIR" ]] && ls "$NGINX_CUSTOM_DIR"/*.conf &>/dev/null; then
        nginx_test_reload
    else
        log_warn "No custom nginx configs rendered"
    fi

    log_info "post-install done"
}

main "$@"
