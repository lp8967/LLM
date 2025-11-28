import streamlit as st
import requests
import os
from dotenv import load_dotenv

load_dotenv()

class Sidebar:
    def __init__(self):
        self.backend_url = os.getenv("BACKEND_URL", "http://localhost:8000")
    
    def render(self):
        """Рендерит боковую панель с настройками"""
        with st.sidebar:
            st.title("Academic Research Assistant")
            st.markdown("---")
            
            # Настройки RAG стратегии
            st.subheader("RAG Settings")
            
            # Выбор стратегии
            strategies = self._get_available_strategies()
            selected_strategy = st.selectbox(
                "RAG Strategy",
                options=list(strategies.keys()),
                index=0,
                help="Choose RAG strategy for search"
            )
            
            # Количество результатов
            top_k = st.slider(
                "Number of results (top_k)",
                min_value=1,
                max_value=10,
                value=3,
                help="Number of research papers to retrieve"
            )
            
            # Настройки сессии
            st.subheader("Session Settings")
            session_id = st.text_input(
                "Session ID", 
                value="default_session",
                help="Unique session identifier for conversation history"
            )
            
            # Кнопка очистки истории
            if st.button("Clear Conversation History"):
                if self._clear_conversation(session_id):
                    st.success("Conversation history cleared!")
                else:
                    st.error("Failed to clear conversation history")
            
            # Информация о системе
            st.markdown("---")
            st.subheader("System Info")
            self._display_system_info()
            
            return {
                "strategy": strategies[selected_strategy],
                "top_k": top_k,
                "session_id": session_id
            }
    
    def _get_available_strategies(self):
        """Получает доступные стратегии RAG из бэкенда"""
        try:
            response = requests.get(f"{self.backend_url}/strategies", timeout=5)
            if response.status_code == 200:
                data = response.json()
                return {s.capitalize(): s for s in data["available_strategies"]}
        except Exception as e:
            st.error(f"Failed to load strategies: {e}")
        
        # Fallback стратегии
        return {
            "Basic": "basic",
            "Hybrid": "hybrid", 
            "Hierarchical": "hierarchical",
            "Adaptive": "adaptive"
        }
    
    def _clear_conversation(self, session_id):
        """Очищает историю диалога"""
        try:
            response = requests.delete(f"{self.backend_url}/conversation/{session_id}")
            return response.status_code == 200
        except Exception as e:
            st.error(f"Error clearing conversation: {e}")
            return False
    
    def _display_system_info(self):
        """Отображает информацию о системе"""
        try:
            # Статистика БД
            stats_response = requests.get(f"{self.backend_url}/stats", timeout=5)
            if stats_response.status_code == 200:
                stats = stats_response.json()
                st.write(f"Documents in DB: {stats.get('total_documents', 'N/A')}")
                st.write(f"Embedding Model: {stats.get('embedding_model', 'N/A')}")
                st.write(f"LLM Model: {stats.get('llm_model', 'N/A')}")
            
            # Метрики производительности
            metrics_response = requests.get(f"{self.backend_url}/metrics", timeout=5)
            if metrics_response.status_code == 200:
                metrics = metrics_response.json()
                st.write(f"Avg Response Time: {metrics.get('average_response_time', 'N/A')}s")
                st.write(f"Success Rate: {metrics.get('success_rate', 'N/A')*100:.1f}%")
                st.write(f"Total Requests: {metrics.get('total_requests', 'N/A')}")
                
        except Exception as e:
            st.error(f"Failed to load system info: {e}")