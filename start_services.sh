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

# Функция для запуска тестов
run_tests() {
    echo "=== RUNNING AUTOMATED TESTS ==="
    
    # Даем бэкенду время на полную инициализацию
    sleep 5
    
    # Тест 1: Базовые тесты API
    echo "1. Testing API endpoints..."
    if python -m pytest tests/test_api_integration.py -v --tb=short; then
        echo "API tests: PASSED"
    else
        echo "API tests: FAILED"
        return 1
    fi
    
    # Тест 2: Тесты RAG качества
    echo "2. Testing RAG quality..."
    if python -m pytest tests/test_rag_quality.py -v --tb=short; then
        echo "RAG tests: PASSED"
    else
        echo "RAG tests: FAILED"
        return 1
    fi
    
    # Тест 3: Интеграционные тесты
    echo "3. Testing integration with real data..."
    if python -m pytest tests/test_integration_real_data.py -v --tb=short; then
        echo "Integration tests: PASSED"
    else
        echo "Integration tests: FAILED"
        return 1
    fi
    
    # Тест 4: Бенчмарк тесты (не блокирующие)
    echo "4. Running benchmark tests..."
    if python tests/simple_evaluator.py; then
        echo "Benchmark tests: COMPLETED"
    else
        echo "Benchmark tests: HAS ISSUES"
    fi
    
    echo "=== ALL TESTS COMPLETED ==="
    return 0
}

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
    
    # ЗАПУСК ФРОНТЕНДА ПЕРВЫМ (основной процесс)
    echo "=== STARTING FRONTEND ==="
    cd /app
    streamlit run frontend/app.py \
        --server.port=8501 \
        --server.address=0.0.0.0 \
        --server.headless=true \
        --server.enableCORS=false \
        --server.enableXsrfProtection=false &
    FRONTEND_PID=$!
    
    # Ждем немного перед запуском бэкенда
    sleep 5
    
    # Запуск бэкенда
    echo "=== STARTING BACKEND ==="
    cd /app
    python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
    BACKEND_PID=$!
    
    # Ожидание готовности бэкенда (с новым healths endpoint)
    wait_for_service "Backend" "http://localhost:8000/healths" || exit 1
    
    # Проверяем что фронтенд тоже запустился
    check_port "Frontend" 8501 || echo "⚠️ Frontend port check failed but continuing..."
    check_http "http://localhost:8502/frontend-health" || echo "⚠️ Frontend health check failed but continuing..."
    
    # Запуск автотестов
    echo "=== STARTING AUTOMATED TESTS ==="
    if run_tests; then
        echo "All tests passed successfully"
    else
        echo "Some tests failed, but continuing startup..."
    fi
    
    echo "✅ ALL SERVICES ARE RUNNING!"
    echo "🎨 Frontend: http://localhost:8501"
    echo "📊 Backend: http://localhost:8000"
    echo "❤️ Backend Health: http://localhost:8000/healths"
    echo "❤️ Frontend Health: http://localhost:8502/frontend-health"
    
    # Ждем завершения фронтенда (основной процесс)
    wait $FRONTEND_PID
    
    # Остановка бэкенда при завершении
    kill $BACKEND_PID 2>/dev/null || true
}

main
