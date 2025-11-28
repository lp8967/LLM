import streamlit as st
import requests
import time
import json

class ChatInterface:
    def __init__(self, backend_url):
        self.backend_url = backend_url
    
    def render(self, session_settings):
        """Рендерит основной интерфейс чата"""
        st.header("Academic Research Query")
        
        # Инициализация состояния сессии
        if "messages" not in st.session_state:
            st.session_state.messages = []
        
        if "conversation_history" not in st.session_state:
            st.session_state.conversation_history = []
        
        # Поле ввода вопроса
        question = st.text_area(
            "Enter your research question:",
            placeholder="e.g., What are the latest advancements in transformer architectures?",
            height=100
        )
        
        col1, col2 = st.columns([1, 4])
        
        with col1:
            submit_button = st.button("Search Research Papers", type="primary")
        
        with col2:
            if st.button("Load Conversation History"):
                self._load_conversation_history(session_settings["session_id"])
        
        # Обработка отправки вопроса
        if submit_button and question:
            self._process_query(question, session_settings)
        
        # Отображение истории сообщений
        self._display_conversation_history()
    
    def _process_query(self, question, session_settings):
        """Обрабатывает запрос пользователя"""
        with st.spinner("Searching research papers and generating answer..."):
            try:
                start_time = time.time()
                
                # Отправка запроса к бэкенду
                payload = {
                    "question": question,
                    "top_k": session_settings["top_k"],
                    "strategy": session_settings["strategy"]
                }
                
                response = requests.post(
                    f"{self.backend_url}/query",
                    json=payload,
                    timeout=30
                )
                
                if response.status_code == 200:
                    data = response.json()
                    processing_time = time.time() - start_time
                    
                    # Сохранение в историю
                    message = {
                        "question": question,
                        "answer": data["answer"],
                        "sources": data["sources"],
                        "context": data["context"],
                        "strategy": data.get("strategy", "basic"),
                        "processing_time": data.get("processing_time", processing_time),
                        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
                    }
                    
                    st.session_state.messages.append(message)
                    st.session_state.conversation_history.append(message)
                    
                    # Обновление UI
                    st.rerun()
                    
                else:
                    st.error(f"Error from backend: {response.status_code} - {response.text}")
                    
            except requests.exceptions.Timeout:
                st.error("Request timeout. Please try again.")
            except requests.exceptions.ConnectionError:
                st.error("Cannot connect to backend server. Please check if the server is running.")
            except Exception as e:
                st.error(f"Unexpected error: {str(e)}")
    
    def _load_conversation_history(self, session_id):
        """Загружает историю диалога из бэкенда"""
        try:
            response = requests.get(f"{self.backend_url}/conversation/{session_id}", timeout=10)
            if response.status_code == 200:
                data = response.json()
                st.session_state.conversation_history = data.get("history", [])
                st.session_state.messages = st.session_state.conversation_history.copy()
                st.success(f"Loaded {len(st.session_state.conversation_history)} messages from history")
                st.rerun()
            else:
                st.error("Failed to load conversation history")
        except Exception as e:
            st.error(f"Error loading conversation history: {e}")
    
    def _display_conversation_history(self):
        """Отображает историю диалога"""
        if st.session_state.messages:
            st.markdown("---")
            st.subheader("Conversation History")
            
            for i, message in enumerate(reversed(st.session_state.messages[-10:])):
                with st.expander(f"Q: {message['question'][:50]}... | {message['timestamp']}", expanded=i==0):
                    self._display_message(message)
    
    def _display_message(self, message):
        """Отображает одно сообщение с деталями"""
        # Вопрос
        st.write(f"**Question:** {message['question']}")
        
        # Ответ
        st.write(f"**Answer:** {message['answer']}")
        
        # Детали
        col1, col2, col3 = st.columns(3)
        with col1:
            st.write(f"**Strategy:** {message.get('strategy', 'basic')}")
        with col2:
            st.write(f"**Processing Time:** {message.get('processing_time', 0):.2f}s")
        with col3:
            st.write(f"**Sources:** {len(message['sources'])}")
        
        # Источники
        if message['sources']:
            with st.expander("View Sources"):
                for j, source in enumerate(message['sources']):
                    st.write(f"{j+1}. {source}")