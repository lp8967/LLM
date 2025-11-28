import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import json

class ResultsDisplay:
    def __init__(self):
        pass
    
    def render_analytics(self, messages):
        """Рендерит аналитику по результатам поиска"""
        if len(messages) < 2:
            return
        
        st.markdown("---")
        st.subheader("Search Analytics")
        
        # Создаем DataFrame для анализа
        df_data = []
        for msg in messages:
            df_data.append({
                'question': msg['question'],
                'strategy': msg.get('strategy', 'basic'),
                'processing_time': msg.get('processing_time', 0),
                'sources_count': len(msg.get('sources', [])),
                'answer_length': len(msg.get('answer', ''))
            })
        
        if df_data:
            df = pd.DataFrame(df_data)
            
            # Метрики
            col1, col2, col3, col4 = st.columns(4)
            with col1:
                st.metric("Total Queries", len(df))
            with col2:
                st.metric("Avg Processing Time", f"{df['processing_time'].mean():.2f}s")
            with col3:
                st.metric("Avg Sources", f"{df['sources_count'].mean():.1f}")
            with col4:
                st.metric("Most Used Strategy", df['strategy'].mode().iloc[0] if not df.empty else "N/A")
            
            # Визуализации
            col1, col2 = st.columns(2)
            
            with col1:
                # Распределение по стратегиям
                strategy_counts = df['strategy'].value_counts()
                if not strategy_counts.empty:
                    fig_strategy = px.pie(
                        values=strategy_counts.values,
                        names=strategy_counts.index,
                        title="Strategy Distribution"
                    )
                    st.plotly_chart(fig_strategy, use_container_width=True)
            
            with col2:
                # Время обработки по стратегиям
                if not df.empty:
                    fig_time = px.box(
                        df, 
                        x='strategy', 
                        y='processing_time',
                        title="Processing Time by Strategy"
                    )
                    st.plotly_chart(fig_time, use_container_width=True)
    
    def render_export_options(self, messages):
        """Рендерит опции экспорта результатов"""
        if not messages:
            return
        
        st.markdown("---")
        st.subheader("Export Results")
        
        col1, col2 = st.columns(2)
        
        with col1:
            # Экспорт в JSON
            json_data = json.dumps(messages, indent=2, ensure_ascii=False)
            st.download_button(
                label="Download as JSON",
                data=json_data,
                file_name=f"research_assistant_conversation_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.json",
                mime="application/json"
            )
        
        with col2:
            # Экспорт в CSV
            if messages:
                csv_data = []
                for msg in messages:
                    csv_data.append({
                        'timestamp': msg.get('timestamp', ''),
                        'question': msg.get('question', ''),
                        'answer': msg.get('answer', ''),
                        'strategy': msg.get('strategy', ''),
                        'processing_time': msg.get('processing_time', 0),
                        'sources_count': len(msg.get('sources', [])),
                        'sources': '; '.join(msg.get('sources', []))
                    })
                
                df = pd.DataFrame(csv_data)
                csv_string = df.to_csv(index=False)
                
                st.download_button(
                    label="Download as CSV",
                    data=csv_string,
                    file_name=f"research_assistant_conversation_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.csv",
                    mime="text/csv"
                )