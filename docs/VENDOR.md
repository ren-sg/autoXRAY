# Обновление vendor/autoXRAY

Upstream ([xVRVx/autoXRAY](https://github.com/xVRVx/autoXRAY)) подключён как git submodule в `vendor/autoXRAY`.

Submodule — это **зафиксированный коммит** upstream, а не живая ветка. Обновление = перейти на новый коммит в submodule и (опционально) закоммитить это в wrapper-репо.

## Шпаргалка

```bash
# обновить upstream до последнего main
git submodule update --remote vendor/autoXRAY

# зафиксировать в wrapper-репо (на dev-машине)
git add vendor/autoXRAY
git commit -m "Bump vendor/autoXRAY to latest upstream"
git push

# на VDS после pull
cd /opt/autoxray
git pull
git submodule update --init --recursive
./install.sh
```

## Обычное обновление

```bash
cd /opt/autoxray

git submodule update --remote vendor/autoXRAY

# что подтянулось
cd vendor/autoXRAY && git log -1 --oneline && cd ../..

./install.sh
```

**Важно:** `./install.sh` после bump upstream перегенерирует UUID и ключи VPN — клиенты нужно обновить. Стабильная ссылка подписки: `https://$XRAY_DOMAIN/subscription.json`.

`.env` и `extensions/services/*.env` не затрагиваются.

## Обновление до конкретного коммита или тега

```bash
cd vendor/autoXRAY
git fetch origin
git checkout <commit-or-tag>
cd ../..
git add vendor/autoXRAY
git commit -m "Pin vendor/autoXRAY to <commit-or-tag>"
```

## Clone с submodule

```bash
git clone --recurse-submodules <repo-url> /opt/autoxray
```

Если клонировали без submodule:

```bash
git submodule update --init --recursive
```

## Если правили файлы внутри vendor/

Свои изменения держите в `extensions/` и `install.sh`, **не в vendor/** — они потеряются при update.

Если правки в submodule уже есть:

```bash
cd vendor/autoXRAY
git stash
git fetch origin
git merge origin/main
cd ../..
git add vendor/autoXRAY
git commit -m "Merge upstream autoXRAY"
./install.sh
```

Конфликты решаются внутри `vendor/autoXRAY`, не в корне wrapper-репо.

## Что не трогается при обновлении

| Путь | При `git pull` + submodule update |
|------|-------------------------------------|
| `.env` | сохраняется |
| `extensions/services/*.env` | сохраняется |
| `extensions/` | обновляется из wrapper-репо |
| `vendor/autoXRAY/` | обновляется до зафиксированного/remote коммита |

## См. также

- [DEPLOY.md](DEPLOY.md) — первичный деплой
- [vendor/autoXRAY/README.md](../vendor/autoXRAY/README.md) — документация upstream
