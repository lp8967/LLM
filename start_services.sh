#!/bin/bash

set -e

# Функция ожидания готовности сервиса
wait_for_service() {
    echo "Waiting for $1 to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if python -c "import urllib.request; urllib.request.urlopen('$2')" 2>/dev/null; then
            echo "$1 is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo "$1 failed to start after $max_attempts attempts"
    return 1
}

# Функция инициализации базы данных
initialize_database() {
    echo "=== DATABASE INITIALIZATION ==="
    
    if [ ! -f /app/chroma_db/chroma.sqlite3 ]; then
        echo "Initializing vector database..."
        if python scripts/load_arxiv_data.py; then
            echo "Database initialized successfully"
        else
            echo "Database initialization failed"
            return 1
        fi
    else
        echo "Vector database already exists"
    fi
}

# Основной процесс
main() {
    echo "Starting Academic Research Assistant..."
    
    # Инициализация БД
    initialize_database || exit 1
    
    # Запуск бэкенда
    echo "=== STARTING BACKEND ==="
    python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
    BACKEND_PID=$!
    
    # Запуск фронтенда
    echo "=== STARTING FRONTEND ==="
    python -m streamlit run frontend/app.py \
        --server.port=8501 \
        --server.address=0.0.0.0 \
        --server.headless=true \
        --server.enableCORS=false \
        --server.enableXsrfProtection=false &
    FRONTEND_PID=$!
    
    # Ожидание готовности сервисов
    wait_for_service "Backend" "http://localhost:8000/health" || exit 1
    sleep 10  # Даем Streamlit больше времени на запуск
    
    # Запуск nginx (ОСНОВНОЙ ПРОЦЕСС)
    echo "=== STARTING NGINX PROXY ==="
    nginx -g "daemon off;" &
    NGINX_PID=$!
    
    echo "🚀 All services started!"
    echo "📊 Backend: http://localhost:8000"
    echo "🎨 Frontend: http://localhost:8501" 
    echo "🌐 Proxy: http://localhost:8080"
    
    # Ждем завершения nginx (основной процесс)
    wait $NGINX_PID
    
    # Остановка сервисов при завершении
    kill $BACKEND_PID 2>/dev/null || true
    kill $FRONTEND_PID 2>/dev/null || true
}

main
