import streamlit as st
import os
from dotenv import load_dotenv
from components.sidebar import Sidebar
from components.chat_interface import ChatInterface
from components.results_display import ResultsDisplay

# Конфигурация страницы
st.set_page_config(
    page_title="Academic Research Assistant",
    page_icon="📚",
    layout="wide",
    initial_sidebar_state="expanded"
)

def main():
    """Основная функция Streamlit приложения"""
    
    # Загрузка переменных окружения
    load_dotenv()
    
    # Инициализация компонентов
    sidebar = Sidebar()
    results_display = ResultsDisplay()
    
    # Заголовок приложения
    st.title("Academic Research Assistant")
    st.markdown("""
    AI-powered research assistant that helps you find and understand academic papers from arXiv database.
    Ask questions about scientific topics and get answers based on real research papers.
    """)
    
    # Рендер боковой панели и получение настроек
    session_settings = sidebar.render()
    
    # Инициализация chat interface
    chat_interface = ChatInterface(sidebar.backend_url)
    
    # Рендер основного интерфейса
    chat_interface.render(session_settings)
    
    # Рендер аналитики и опций экспорта
    if "messages" in st.session_state and st.session_state.messages:
        results_display.render_analytics(st.session_state.messages)
        results_display.render_export_options(st.session_state.messages)

if __name__ == "__main__":
    main()