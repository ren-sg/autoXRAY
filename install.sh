#!/bin/bash
# Wrapper: upstream autoXRAY1.sh + extensions layer.

set -euo pipefail

AUTOXRAY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AUTOXRAY_ROOT

# shellcheck source=extensions/lib/common.sh
source "$AUTOXRAY_ROOT/extensions/lib/common.sh"

print_final_status() {
    echo
    log_info "=== Final status ==="

    if ss -tln | grep -q ':443 '; then
        log_info "Port 443: listening (Xray)"
    else
        log_warn "Port 443: not listening"
    fi

    if [[ "$USE_WARP" == "1" ]] && ss -tln | grep -q ':40000'; then
        log_info "WARP SOCKS :40000: listening"
    elif [[ "$USE_WARP" == "1" ]]; then
        log_warn "WARP SOCKS :40000: not listening"
    fi

    if systemctl is-active --quiet nginx; then
        log_info "nginx: running"
    else
        log_warn "nginx: not running"
    fi

    if systemctl is-active --quiet xray; then
        log_info "xray: running"
    else
        log_warn "xray: not running"
    fi

    if [[ -f "$STATE_DIR/state.env" ]]; then
        # shellcheck source=/dev/null
        source "$STATE_DIR/state.env"
        echo
        log_info "VPN domain: $XRAY_DOMAIN"
        [[ -n "${PATH_SUBPAGE:-}" ]] && log_info "Subscription: https://$XRAY_DOMAIN/subscription.json"
        [[ -n "${PATH_SUBPAGE:-}" ]] && log_info "Subscription (direct): https://$XRAY_DOMAIN/$PATH_SUBPAGE.json"
    fi

    local f
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        # shellcheck source=/dev/null
        source "$f"
        log_info "Service: https://${SERVICE_DOMAIN} → ${SERVICE_UPSTREAM}"
    done < <(list_service_env_files)
}

main() {
    require_root
    load_env

    log_info "autoXRAY extensions install"
    log_info "XRAY_DOMAIN=$XRAY_DOMAIN"

    check_all_dns

    local upstream="$AUTOXRAY_ROOT/vendor/autoXRAY/autoXRAY1.sh"
    if [[ ! -f "$upstream" ]]; then
        log_error "Не найден $upstream"
        log_error "Выполните: git submodule update --init --recursive"
        exit 1
    fi

    log_info "Running upstream autoXRAY1.sh ..."
    bash "$upstream" "$XRAY_DOMAIN"

    bash "$AUTOXRAY_ROOT/extensions/lib/state.sh" save
    bash "$AUTOXRAY_ROOT/extensions/post-install.sh"

    print_final_status
    log_info "Install complete. Re-run: ./install.sh (not autoXRAY1.sh alone)"
}

main "$@"
