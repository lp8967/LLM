#!/bin/bash
set -e

# --- Инициализация базы данных ---
echo "=== DATABASE INITIALIZATION ==="
if [ ! -f /app/chroma_db/chroma.sqlite3 ]; then
    echo "Initializing vector database..."
    python scripts/load_arxiv_data.py
else
    echo "Vector database already exists"
fi

# --- Запуск FastAPI в фоне ---
echo "=== STARTING BACKEND ==="
cd /app
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!

# --- Ожидание готовности бэкенда ---
echo "Waiting for Backend to be ready..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" 2>/dev/null; then
        echo "Backend is ready!"
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done

# --- Запуск автотестов (не блокирующих основной процесс) ---
echo "=== STARTING AUTOMATED TESTS ==="
python -m pytest tests/test_api_integration.py -v --tb=short || echo "Some tests failed"
python -m pytest tests/test_rag_quality.py -v --tb=short || echo "Some tests failed"
python -m pytest tests/test_integration_real_data.py -v --tb=short || echo "Some tests failed"
python tests/simple_evaluator.py || echo "Benchmark tests have issues"

# --- Запуск Streamlit как главного процесса ---
echo "=== STARTING FRONTEND ==="
streamlit run frontend/app.py \
    --server.port=$PORT \
    --server.address=0.0.0.0 \
    --server.headless=true \
    --server.enableCORS=false \
    --server.enableXsrfProtection=false

# --- Остановка бэкенда при завершении ---
kill $BACKEND_PID 2>/dev/null || true
