FROM python:3.9-slim

WORKDIR /app

# Копируем requirements первыми для кэширования
COPY requirements.txt .
COPY requirements-test.txt .

# Устанавливаем зависимости
RUN pip install --no-cache-dir -r requirements.txt -r requirements-test.txt

# Копируем весь код
COPY . .

# Создаем необходимые директории
RUN mkdir -p chroma_db data

# Делаем скрипт запуска исполняемым
RUN chmod +x start_services.sh

# Порты
EXPOSE 8000 8501

# Переменные окружения
ENV PYTHONPATH=/app
ENV STREAMLIT_SERVER_PORT=8501
ENV STREAMLIT_SERVER_HEADLESS=true

# Health check на чистом Python
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8501')" || exit 1

# Запуск сервисов
CMD ["./start_services.sh"]