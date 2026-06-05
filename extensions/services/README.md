# Дополнительные сервисы (nginx proxy)

Каждый сервис — отдельный файл `extensions/services/<name>.env` на сервере (не в git).

## Добавление сервиса

1. DNS: A-запись `app.example.com` → IP VPS.
2. Скопировать шаблон:

```bash
cp extensions/services/example.env.example extensions/services/myapp.env
nano extensions/services/myapp.env
```

3. Применить:

```bash
./install.sh
# или только nginx + cert:
./extensions/post-install.sh
```

4. Запустить upstream (Docker и т.п.) на `127.0.0.1:PORT` из `SERVICE_UPSTREAM`.

## Поля

| Переменная | Описание |
|------------|----------|
| `SERVICE_NAME` | Имя для имён файлов nginx (`10-<name>-ssl.conf`) |
| `SERVICE_DOMAIN` | Поддомен (SNI / certbot) |
| `SERVICE_UPSTREAM` | URL upstream, напр. `http://127.0.0.1:5678` |
| `SERVICE_WEBSOCKET` | `1` — заголовки Upgrade для WebSocket |

## HTTPS

Внешний `:443` слушает Xray. Браузерный HTTPS идёт: Xray fallback → nginx (unix-socket) → upstream.

Upstream **не** биндится на `:443` хоста — только localhost-порт.
