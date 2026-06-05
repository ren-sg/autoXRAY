#!/bin/bash
# Shared helpers for autoXRAY extensions.

AUTOXRAY_ROOT="${AUTOXRAY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

GRN='\033[1;32m'
RED='\033[1;31m'
YEL='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GRN}[info]${NC} $*"; }
log_warn()  { echo -e "${YEL}[warn]${NC} $*"; }
log_error() { echo -e "${RED}[error]${NC} $*" >&2; }

require_root() {
    [[ $EUID -eq 0 ]] || { log_error "Нужны root права"; exit 1; }
}

load_env() {
    local env_file="${1:-$AUTOXRAY_ROOT/.env}"
    if [[ ! -f "$env_file" ]]; then
        log_error "Не найден $env_file — скопируйте .env.example в .env"
        exit 1
    fi
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a

    : "${XRAY_DOMAIN:?XRAY_DOMAIN не задан в .env}"
    : "${CERTBOT_EMAIL:?CERTBOT_EMAIL не задан в .env}"
    USE_WARP="${USE_WARP:-1}"
    NGINX_CUSTOM_DIR="${NGINX_CUSTOM_DIR:-/etc/nginx/conf.d/autoxray-custom}"
    STATE_DIR="${STATE_DIR:-/etc/autoXRAY}"
}

nginx_config_path() {
    if [[ -f /etc/nginx/sites-available/default ]]; then
        echo /etc/nginx/sites-available/default
    elif [[ -f /etc/nginx/conf.d/default.conf ]]; then
        echo /etc/nginx/conf.d/default.conf
    else
        log_error "Не найден default-конфиг nginx"
        exit 1
    fi
}

nginx_test_reload() {
    nginx -t || { log_error "nginx -t failed"; exit 1; }
    systemctl reload nginx
    log_info "nginx reloaded"
}

check_dns() {
    local domain="$1"
    local local_ip
    local_ip=$(hostname -I | awk '{print $1}')
    local dns_ip
    dns_ip=$(dig +short "$domain" | grep -m1 '^[0-9]')

    if [[ -z "$dns_ip" ]]; then
        log_warn "DNS: нет A-записи для $domain"
        return 1
    fi
    if [[ "$local_ip" != "$dns_ip" ]]; then
        log_warn "DNS: $domain → $dns_ip, локальный IP → $local_ip"
        return 1
    fi
    log_info "DNS OK: $domain → $dns_ip"
    return 0
}

check_all_dns() {
    local failed=0
    check_dns "$XRAY_DOMAIN" || failed=1

    local f
    shopt -s nullglob
    for f in "$AUTOXRAY_ROOT/extensions/services/"*.env; do
        [[ "$f" == *.example ]] && continue
        # shellcheck source=/dev/null
        source "$f"
        if [[ -n "${SERVICE_DOMAIN:-}" ]]; then
            check_dns "$SERVICE_DOMAIN" || failed=1
        fi
    done
    shopt -u nullglob

    if [[ $failed -eq 1 ]]; then
        read -r -p "Продолжить несмотря на DNS? (y/N): " choice
        [[ "$choice" =~ ^[Yy]$ ]] || exit 1
    fi
}

list_service_env_files() {
    local f
    shopt -s nullglob
    for f in "$AUTOXRAY_ROOT/extensions/services/"*.env; do
        [[ "$f" == *.example ]] && continue
        echo "$f"
    done
    shopt -u nullglob
}
