from flask import Flask, jsonify
import threading

# Создаем Flask app для health check фронтенда
health_app = Flask(__name__)

@health_app.route('/frontend-health')
def frontend_health_check():
    return jsonify({
        "status": "healthy", 
        "service": "streamlit-frontend"
    })

def start_frontend_health_server():
    """Запускает health server для фронтенда в отдельном потоке"""
    health_app.run(host='0.0.0.0', port=8502, debug=False)

# Запускаем health server при импорте
threading.Thread(target=start_frontend_health_server, daemon=True).start()