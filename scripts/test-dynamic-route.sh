#!/usr/bin/env bash
# Тестовый запрос к маршруту, использующему Puppeteer (Browserless).
# Запуск: из корня репозитория, при поднятых контейнерах с browserless:
#   docker compose -f docker-compose.yml -f docker-compose.browserless.yml up -d
#   ./scripts/test-dynamic-route.sh

set -e
cd "$(dirname "$0")/.."
BASE="${RSSHUB_BASE_URL:-http://localhost:1200}"
ROUTE="${1:-/xiaohongshu/board/5db6f79200000000020032df}"

echo "=== Тест динамического маршрута (Puppeteer/Browserless) ==="
echo "URL: ${BASE}${ROUTE}"
echo ""

OUT=$(mktemp)
HTTP=$(curl -s -w "%{http_code}" -o "$OUT" "${BASE}${ROUTE}")
echo "HTTP: $HTTP"
echo ""

if echo "$(head -1 "$OUT")" | grep -q '<?xml\|<rss'; then
  echo "Ответ: RSS (первые строки):"
  head -15 "$OUT"
else
  echo "Ответ (первые 20 строк):"
  head -20 "$OUT"
fi
echo ""
echo "--- Логи Browserless (подтверждение использования браузера) ---"
docker compose -f docker-compose.yml -f docker-compose.browserless.yml logs browserless --tail 6 2>&1 | grep -E 'browserless:(server|job|chrome)' || true
rm -f "$OUT"
echo ""
echo "Готово. При успешном использовании Puppeteer в логах видны 'Recording successful stat' или 'Setting up page'."
