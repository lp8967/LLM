#!/bin/bash

set -e

# Функция проверки порта
check_port() {
    echo "Checking if $1 is ready on port $2..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if python -c "import socket; s = socket.socket(); s.settimeout(1); s.connect(('127.0.0.1', $2)); s.close()" 2>/dev/null; then
            echo "✅ $1 is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo "❌ $1 failed to start after $max_attempts attempts"
    return 1
}

# Функция проверки HTTP endpoint
check_http() {
    echo "Checking HTTP endpoint: $1..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if python -c "import urllib.request; urllib.request.urlopen('$1')" 2>/dev/null; then
            echo "✅ HTTP endpoint $1 is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo "❌ HTTP endpoint $1 failed after $max_attempts attempts"
    return 1
}

# Функция инициализации базы данных
initialize_database() {
    echo "=== DATABASE INITIALIZATION ==="
    
    if [ ! -f /app/chroma_db/chroma.sqlite3 ]; then
        echo "Initializing vector database..."
        if python scripts/load_arxiv_data.py; then
            echo "✅ Database initialized successfully"
        else
            echo "❌ Database initialization failed"
            return 1
        fi
    else
        echo "✅ Vector database already exists"
    fi
}

# Основной процесс
main() {
    echo "🚀 Starting Academic Research Assistant..."
    
    # Инициализация БД
    initialize_database || exit 1
    
    # ЗАПУСК ФРОНТЕНДА ПЕРВЫМ
    echo "=== STARTING FRONTEND ==="
    python -m streamlit run frontend/app.py \
        --server.port=8501 \
        --server.address=0.0.0.0 \
        --server.headless=true \
        --server.enableCORS=false \
        --server.enableXsrfProtection=false &
    FRONTEND_PID=$!
    
    # Ждем готовности фронтенда
    check_port "Frontend" 8501 || exit 1
    echo "✅ Frontend is running on port 8501"
    
    # ЗАПУСК БЭКЕНДА ПОСЛЕ фронтенда
    echo "=== STARTING BACKEND ==="
    python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
    BACKEND_PID=$!
    
    # Ждем готовности бэкенда
    check_port "Backend" 8000 || exit 1
    check_http "http://localhost:8000/health" || exit 1
    echo "✅ Backend is running on port 8000 with health check"
    
    echo "✅ ALL SERVICES ARE RUNNING!"
    echo "🎨 Frontend: http://localhost:8501"
    echo "📊 Backend: http://localhost:8000"
    echo "❤️ Health check: http://localhost:8000/health"
    
    # Ждем завершения фронтенда (основной процесс)
    wait $FRONTEND_PID
    
    # Если фронтенд упал, останавливаем бэкенд
    kill $BACKEND_PID 2>/dev/null || true
}

main
