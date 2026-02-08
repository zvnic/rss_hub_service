# RSSHub — развёртывание через Docker Compose

Конфигурация для запуска [RSSHub](https://github.com/DIYgod/RSSHub) на собственном сервере с настройкой через переменные окружения.

## Две версии конфигурации

| Вариант | Сервисы | Когда использовать |
|--------|---------|--------------------|
| **Базовая** | RSSHub + Redis | Локально или за внешним reverse proxy (Nginx/Caddy на хосте) |
| **Расширенная** | RSSHub + Redis + Nginx + Prometheus | Полный стек на одном хосте: прокси, метрики, один `docker compose` |

### Запуск базовой версии (RSSHub + Redis)

```bash
cp .env.example .env
# Отредактируйте .env и обязательно задайте REDIS_PASSWORD
docker compose up -d
```

RSSHub будет доступен на порту **1200** (или на значении `RSSHUB_PORT` из `.env`).

### Запуск расширенной версии (с Nginx и Prometheus)

```bash
cp .env.example .env
# Задайте REDIS_PASSWORD и при необходимости порты/домен
docker compose -f docker-compose.yml -f docker-compose.full.yml up -d
```

- RSSHub доступен только через **Nginx** (порты 80/443).
- Метрики: **Prometheus** на порту 9090 (или `PROMETHEUS_PORT`).

---

## Быстрый старт

1. Клонируйте репозиторий или скопируйте файлы в каталог проекта.
2. Создайте `.env` из примера и задайте **надёжный пароль Redis**:
   ```bash
   cp .env.example .env
   # В .env замените: REDIS_PASSWORD=your_secure_redis_password
   ```
3. Запустите один из вариантов:
   - Базовая: `docker compose up -d`
   - Расширенная: `docker compose -f docker-compose.yml -f docker-compose.full.yml up -d`
4. Проверьте:
   - Базовая: <http://localhost:1200>
   - Расширенная: <http://localhost:80>

Все сервисы поднимаются одной командой; конфигурация задаётся через `.env`.

---

## Переменные окружения

### Обязательные

- **REDIS_PASSWORD** — пароль Redis. Задайте свой; в продакшене не оставляйте значение из примера.

### Опциональные (имеют значения по умолчанию)

- **RSSHUB_PORT** — порт RSSHub на хосте (по умолчанию 1200).
- **RSSHUB_NODE_ENV** — окружение (по умолчанию `production`).
- **RSSHUB_LOGGER_LEVEL** — уровень логов (по умолчанию `info`).
- **CACHE_EXPIRE**, **CACHE_CONTENT_EXPIRE** — время жизни кэша (секунды).
- **ALLOW_ORIGIN** — CORS (по умолчанию `*`).
- **PUPPETEER_WS_ENDPOINT** — WebSocket Puppeteer (пусто = не используется).
- **PROXY_URI**, **PROXY_AUTH** — прокси для запросов RSSHub.
- **NGINX_PORT_HTTP**, **NGINX_PORT_HTTPS**, **DOMAIN_NAME**, **EMAIL** — для расширенного варианта и SSL.
- **PROMETHEUS_PORT**, **METRICS_ENABLED** — для расширенного варианта и метрик.

Полный список и пояснения — в `.env.example`.

---

## Структура проекта

```
.
├── docker-compose.yml          # Базовая конфигурация (RSSHub + Redis)
├── docker-compose.full.yml     # Расширенная (+ Nginx + Prometheus)
├── .env.example                # Пример переменных окружения
├── nginx/
│   ├── nginx.conf              # Конфиг Nginx (HTTP, без SSL по умолчанию)
│   └── nginx.ssl.conf.example  # Пример конфига с SSL
├── prometheus/
│   └── prometheus.yml          # Конфиг сбора метрик
├── data/                       # Создаётся при запуске (в .gitignore)
│   ├── redis/                  # Данные Redis
│   └── certbot/                # Сертификаты и challenge (при использовании SSL)
└── README.md
```

---

## Health checks

Во всех конфигурациях включены проверки состояния:

- **RSSHub**: `GET http://localhost:1200/healthz`
- **Redis**: `redis-cli ping`
- **Nginx** (расширенная): `GET http://127.0.0.1:80/healthz`
- **Prometheus** (расширенная): `GET http://localhost:9090/-/healthy`

Используйте их для мониторинга и `depends_on` в Docker Compose.

---

## SSL (Let's Encrypt)

По умолчанию Nginx настроен только на HTTP. Чтобы включить HTTPS:

1. Убедитесь, что домен указывает на ваш сервер и порты 80/443 открыты.
2. Создайте каталоги и получите сертификат (пример с certbot в Docker):
   ```bash
   mkdir -p data/certbot/www data/certbot/conf
   docker run --rm -p 80:80 -v $(pwd)/data/certbot/www:/var/www/certbot -v $(pwd)/data/certbot/conf:/etc/letsencrypt certbot/certbot certonly --standalone -d rsshub.yourdomain.com --email admin@yourdomain.com --agree-tos
   ```
3. Подключите сертификаты к Nginx:
   - смонтируйте `./data/certbot/conf/live/ВАШ_ДОМЕН/` в контейнер Nginx (например, в `/etc/nginx/ssl`) и
   - используйте конфиг по образцу `nginx/nginx.ssl.conf.example` (или объедините его с основным `nginx.conf`).
4. В `nginx.conf` укажите ваш `server_name` вместо `localhost`.

Подробности по вашей ОС и certbot см. в [документации Let's Encrypt](https://letsencrypt.org/docs/).

---

## Ограничение ресурсов и логи

В `docker-compose.yml` заданы лимиты памяти и настройки логирования:

- RSSHub: лимит 512M, логи `json-file`, max-size 10m, 3 файла.
- Redis: лимит 256M, логи 5m, 2 файла.
- В расширенной конфигурации аналогично ограничены Nginx и Prometheus.

При необходимости измените `deploy.resources` и `logging.options` в compose-файлах.

---

## Использование за reverse proxy на хосте

Если Nginx/Caddy/Traefik уже стоят на хосте:

1. Используйте **базовую** конфигурацию: `docker compose up -d`.
2. В прокси на хосте настройте upstream на `http://127.0.0.1:1200` (или на хост и порт, куда проброшен `RSSHUB_PORT`).
3. SSL и rate limiting настраивайте на стороне хоста.

---

## Обновление контейнеров

```bash
docker compose pull
docker compose up -d
```

Для расширенной версии:

```bash
docker compose -f docker-compose.yml -f docker-compose.full.yml pull
docker compose -f docker-compose.yml -f docker-compose.full.yml up -d
```

---

## Бэкап и восстановление Redis

Данные Redis хранятся в `./data/redis` (базовая и расширенная конфигурация).

**Бэкап (RDB или копирование директории):**

```bash
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" BGSAVE
cp -r ./data/redis ./backup/redis-$(date +%Y%m%d)
```

**Восстановление:** остановите контейнеры, замените содержимое `./data/redis` на данные из бэкапа, затем снова запустите `docker compose up -d`.

---

## Полезные команды

| Действие | Базовая | Расширенная |
|----------|---------|-------------|
| Запуск | `docker compose up -d` | `docker compose -f docker-compose.yml -f docker-compose.full.yml up -d` |
| Остановка | `docker compose down` | `docker compose -f docker-compose.yml -f docker-compose.full.yml down` |
| Логи | `docker compose logs -f rsshub` | `docker compose -f docker-compose.yml -f docker-compose.full.yml logs -f rsshub` |
| Логи всех сервисов | `docker compose logs -f` | то же с двумя файлами |

---

## Устранение неполадок

**Ошибка при загрузке образа:** `failed to register layer: archive/tar: invalid tar header`

Возможные причины: кэш Docker, нехватка места на диске или сбой при загрузке слоя. Попробуйте по порядку:

1. Перезапустите Docker Desktop и повторите `docker compose up -d`.
2. Очистите кэш и повторно загрузите образы:
   ```bash
   docker compose down
   docker rmi diygod/rsshub:latest 2>/dev/null
   docker builder prune -af
   docker compose pull
   docker compose up -d
   ```
3. Убедитесь, что на диске достаточно свободного места (образ ~150 MB).
4. Обновите Docker Desktop до последней версии.

---

## Безопасность

- Не используйте дефолтные пароли: обязательно задайте **REDIS_PASSWORD** в `.env`.
- Файл `.env` не коммитьте в репозиторий (он в `.gitignore`).
- Для доступа к RSSHub с ключом настройте **ACCESS_KEY** в `.env` и при необходимости измените healthcheck (см. [документацию RSSHub](https://docs.rsshub.app/deploy/config)).
- При публичном доступе ограничьте **ALLOW_ORIGIN** списком доверенных доменов.

---

## Маршруты RSSHub и переменные

Конкретные маршруты (Bilibili, Twitter, GitHub и т.д.) и их параметры задаются переменными окружения по [документации RSSHub](https://docs.rsshub.app/). Добавляйте нужные переменные в `.env` и перезапускайте контейнеры:

```bash
docker compose up -d --force-recreate rsshub
```
