FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-devel

# Отключение интерактивных запросов во время сборки
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Обновление pip
RUN pip install --upgrade pip setuptools wheel

# Создание рабочей директории
WORKDIR /app

# Создание пользователя для безопасности
RUN useradd -m -u 1000 -s /bin/bash appuser \
    && mkdir -p /app/temp /app/logs \
    && chown -R appuser:appuser /app

# PyTorch уже установлен в базовом образе

# Копирование requirements и установка остальных зависимостей
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Копирование кода приложения
COPY app.py crypto_utils.py /app/
RUN chown -R appuser:appuser /app

# Переключение на пользователя appuser
USER appuser

# Предзагрузка модели Whisper (базовая модель для тестирования)
RUN python -c "from faster_whisper import WhisperModel; WhisperModel('base', device='cpu', compute_type='int8')" || true

# Создание точки входа
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Проверка переменных окружения\n\
if [ -z "$SECRET_ENDPOINT" ] || [ -z "$KEY_DECRYPT" ] || [ -z "$KEY_ENCRYPT" ]; then\n\
    echo "❌ Ошибка: Не настроены переменные окружения!"\n\
    echo "Требуются: SECRET_ENDPOINT, KEY_DECRYPT, KEY_ENCRYPT"\n\
    exit 1\n\
fi\n\
\n\
# Проверка PyTorch\n\
python -c "import torch; print(f\"🔥 PyTorch: {torch.__version__}\"); print(f\"🎮 CUDA: {torch.cuda.is_available()}\")" || echo "⚠️ PyTorch проблема"\n\
\n\
# Проверка GPU\n\
if command -v nvidia-smi &> /dev/null; then\n\
    echo "🎮 GPU Information:"\n\
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1 || echo "GPU недоступен"\n\
else\n\
    echo "⚠️ GPU не обнаружен, используется CPU"\n\
fi\n\
\n\
# Создание необходимых директорий\n\
mkdir -p /app/temp /app/logs\n\
\n\
# Запуск приложения\n\
echo "🚀 Запуск Stenogramma на порту 8000..."\n\
exec uvicorn app:app --host 0.0.0.0 --port 8000 --workers 1' > /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/endpoint_info || exit 1

# Экспозиция порта
EXPOSE 8000

# Запуск
ENTRYPOINT ["/app/entrypoint.sh"]
