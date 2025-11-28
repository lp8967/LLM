FROM python:3.9-slim

WORKDIR /app

# Устанавливаем nginx
RUN apt-get update && apt-get install -y nginx && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Копируем requirements первыми для кэширования
COPY requirements.txt .
COPY requirements-test.txt .

# Устанавливаем зависимости
RUN pip install --no-cache-dir -r requirements.txt -r requirements-test.txt

# Копируем весь код
COPY . .

# Копируем nginx конфиг
COPY nginx.conf /etc/nginx/nginx.conf

# Создаем необходимые директории
RUN mkdir -p chroma_db data

# Делаем скрипт запуска исполняемым
RUN chmod +x start_services.sh

# Порты
EXPOSE 8080

# Переменные окружения
ENV PYTHONPATH=/app
ENV STREAMLIT_SERVER_PORT=8501
ENV STREAMLIT_SERVER_HEADLESS=true

# Health check на nginx порт
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

# Запуск сервисов
CMD ["./start_services.sh"]
