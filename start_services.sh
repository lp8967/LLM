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
    
    # ЗАПУСК БЭКЕНДА ПЕРВЫМ (для health check)
    echo "=== STARTING BACKEND ==="
    python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
    BACKEND_PID=$!
    
    # Ждем готовности бэкенда
    check_port "Backend" 8000 || exit 1
    
    # ЗАПУСК ФРОНТЕНДА КАК ОСНОВНОГО ПРОЦЕССА
    echo "=== STARTING FRONTEND (MAIN PROCESS) ==="
    
    # Запускаем Streamlit как ОСНОВНОЙ процесс (блокирующий)
    exec python -m streamlit run frontend/app.py \
        --server.port=8501 \
        --server.address=0.0.0.0 \
        --server.headless=true \
        --server.enableCORS=false \
        --server.enableXsrfProtection=false
    
    # Код ниже не выполнится, потому что exec заменил процесс
}

main
