#!/bin/bash
set -e

# переменные
NGINX_CONF_TEMPLATE=./nginx/nginx.conf
NGINX_CONF=/etc/nginx/nginx.conf

# init DB
if [ ! -f /app/chroma_db/chroma.sqlite3 ]; then
    python scripts/load_arxiv_data.py
fi

# Запуск FastAPI и Streamlit на внутренних портах
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 &
BACKEND_PID=$!

streamlit run frontend/app.py \
    --server.port=8501 \
    --server.address=127.0.0.1 \
    --server.headless=true \
    --server.enableCORS=false \
    --server.enableXsrfProtection=false &
STREAMLIT_PID=$!

# Ждём оба сервиса
echo "Waiting for backend..."
until python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')" 2>/dev/null; do sleep 1; done
echo "Waiting for streamlit..."
until python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8501')" 2>/dev/null; do sleep 1; done

# Подготовим nginx.conf с заменой $PORT
echo "Configuring nginx..."
export PORT=${PORT:-8080}
envsubst '\$PORT' < $NGINX_CONF_TEMPLATE > /tmp/nginx.conf

# Копируем конфиг и запускаем nginx в foreground (Render считает этот процесс главным)
sudo cp /tmp/nginx.conf $NGINX_CONF
nginx -g 'daemon off;'
# при остановке nginx скрипт завершится: убиваем фоны
kill $BACKEND_PID $STREAMLIT_PID 2>/dev/null || true
