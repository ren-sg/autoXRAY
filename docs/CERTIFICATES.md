# Сертификаты Let's Encrypt

Все HTTPS-сертификаты выпускает **certbot** (Let's Encrypt).

| Параметр | Значение |
|----------|----------|
| Срок действия | **90 дней** |
| Авто-продление | `certbot.timer` (systemd), обычно 2 раза в день |
| Продление заранее | certbot renew — когда до истечения ≤ 30 дней |

## Какие домены и кто выпускает

| Домен | Скрипт | Путь к cert |
|-------|--------|-------------|
| `XRAY_DOMAIN` (VPN) | upstream `vendor/autoXRAY/autoXRAY1.sh` | `/etc/letsencrypt/live/$XRAY_DOMAIN/` |
| Копия для Xray TLS `:8443` | upstream deploy-hook | `/var/lib/xray/cert/` |
| `SERVICE_DOMAIN` (app-поддомены) | `extensions/post-install.sh` | `/etc/letsencrypt/live/$SERVICE_DOMAIN/` |

Проверка ACME: HTTP **:80** → `/.well-known/acme-challenge/` (webroot `/var/www/html`).

## Авто-обновление

### VPN-домен (`XRAY_DOMAIN`)

Upstream регистрирует **per-cert deploy-hook** при первой выдаче:

- `systemctl reload nginx`
- копия cert в `/var/lib/xray/cert/`
- `systemctl restart xray`

### Поддомены сервисов

`extensions/post-install.sh`:

1. При **первой выдаче** cert — `--deploy-hook "systemctl reload nginx"`.
2. Глобальный hook для **всех** renew (в т.ч. уже существующих cert):

```
/etc/letsencrypt/renewal-hooks/deploy/autoxray-reload-nginx.sh
```

Создаётся/обновляется при каждом `./install.sh` или `./extensions/post-install.sh`.

## Проверка

```bash
# список cert и даты истечения
certbot certificates

# таймер авто-продления
systemctl status certbot.timer

# тест продления без изменений
certbot renew --dry-run

# даты конкретного cert
openssl x509 -in /etc/letsencrypt/live/DOMAIN/cert.pem -noout -dates
```

## Ручное продление

Обычно не требуется — срабатывает `certbot.timer`. При необходимости:

```bash
certbot renew
# или один домен:
certbot certonly --webroot -w /var/www/html -d app.example.com --force-renewal
systemctl reload nginx
```

После renew VPN-домена upstream deploy-hook сам перезапустит xray и обновит `/var/lib/xray/cert/`.

## Перевыпуск после `./install.sh`

| Домен | Поведение |
|-------|-----------|
| `XRAY_DOMAIN` | upstream вызывает certbot (LE вернёт существующий или обновит) |
| `SERVICE_DOMAIN` | post-install пропускает, если cert уже есть |

Полная переустановка cert сервиса:

```bash
certbot delete --cert-name app.example.com
./extensions/post-install.sh
```

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| certbot fails | DNS A-запись → VPS, порт 80 открыт, nginx отдаёт webroot |
| HTTPS работает, но старый cert после renew | `systemctl reload nginx`; проверить hook: `ls /etc/letsencrypt/renewal-hooks/deploy/` |
| Xray :8443 с протухшим cert | `certbot renew` для `XRAY_DOMAIN`; upstream deploy-hook обновит `/var/lib/xray/cert/` |
| timer не активен | `systemctl enable --now certbot.timer` |

## См. также

- [DEPLOY.md](DEPLOY.md) — первичный деплой
- [VENDOR.md](VENDOR.md) — обновление upstream
