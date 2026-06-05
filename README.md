# autoXRAY extensions

Обёртка над [xVRVx/autoXRAY](https://github.com/xVRVx/autoXRAY): VPN (Xray REALITY) + nginx-прокси для дополнительных поддоменов (Docker и т.п.).

Upstream подключается как git submodule: [`vendor/autoXRAY`](vendor/autoXRAY).

## Быстрый старт

```bash
git clone --recurse-submodules <this-repo-url> /opt/autoxray
cd /opt/autoxray
cp .env.example .env && nano .env
cp extensions/services/example.env.example extensions/services/myapp.env && nano extensions/services/myapp.env
./install.sh
```

Если submodule не подтянулся:

```bash
git submodule update --init --recursive
```

## Документация

- [docs/DEPLOY.md](docs/DEPLOY.md) — деплой на Ubuntu 24.04
- [docs/VENDOR.md](docs/VENDOR.md) — обновление submodule upstream
- [extensions/services/README.md](extensions/services/README.md) — добавление сервисов
- [vendor/autoXRAY/README.md](vendor/autoXRAY/README.md) — upstream VPN

## Структура

| Путь | Описание |
|------|----------|
| `install.sh` | Установка: upstream + extensions |
| `extensions/` | nginx, certbot, post-install |
| `vendor/autoXRAY/` | Submodule [xVRVx/autoXRAY](https://github.com/xVRVx/autoXRAY) |
| `.env` | Реальные домены (не в git) |

## Обновление upstream

См. [docs/VENDOR.md](docs/VENDOR.md).
