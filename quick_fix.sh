#!/bin/bash

# Быстрое исправление проблемы с PyTorch в Dockerfile
# Версия: 1.0.0

set -e

echo "🔧 Быстрое исправление PyTorch проблемы..."

# Создание исправленного Dockerfile
cat > Dockerfile << 'EOF'
FROM nvidia/cuda:12.1-runtime-ubuntu22.04

# Отключение интерактивных запросов во время сборки
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3.10-dev \
    python3-pip \
    python3.10-venv \
    ffmpeg \
    libsndfile1 \
    curl \
    wget \
    git \
    build-essential \
    pkg-config \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Создание символической ссылки для python
RUN ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python

# Обновление pip
RUN python3 -m pip install --upgrade pip setuptools wheel

# Создание рабочей директории
WORKDIR /app

# Создание пользователя для безопасности
RUN useradd -m -u 1000 -s /bin/bash appuser \
    && mkdir -p /app/temp /app/logs \
    && chown -R appuser:appuser /app

# Установка PyTorch с fallback стратегией
RUN pip3 install --no-cache-dir torch torchvision torchaudio || \
    pip3 install --no-cache-dir torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 || \
    pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Копирование requirements и установка остальных зависимостей
COPY requirements.txt /app/
RUN pip3 install --no-cache-dir -r requirements.txt

# Копирование кода приложения
COPY app.py crypto_utils.py /app/
RUN chown -R appuser:appuser /app

# Переключение на пользователя appuser
USER appuser

# Предзагрузка модели Whisper (базовая модель для тестирования)
RUN python3 -c "from faster_whisper import WhisperModel; WhisperModel('base', device='cpu', compute_type='int8')" || true

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
python3 -c "import torch; print(f\"🔥 PyTorch: {torch.__version__}\"); print(f\"🎮 CUDA: {torch.cuda.is_available()}\")" || echo "⚠️ PyTorch проблема"\n\
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
EOF

echo "✅ Dockerfile исправлен с fallback PyTorch установкой"

# Создание простого тестового скрипта
cat > test_build.sh << 'EOF'
#!/bin/bash
echo "🧪 Тестирование сборки..."

# Проверка ключей
if [ ! -f ".env" ]; then
    echo "📝 Генерация ключей..."
    python3 generate_keys.py
fi

# Сборка образа
echo "🔨 Сборка Docker образа..."
docker build -t stenogramma:test .

if [ $? -eq 0 ]; then
    echo "✅ Сборка успешна!"
    echo "🚀 Попробуйте запустить: ./run_docker.sh start"
else
    echo "❌ Ошибка сборки"
    exit 1
fi
EOF

chmod +x test_build.sh

echo "✅ Создан test_build.sh для проверки сборки"
echo ""
echo "📋 Следующие шаги:"
echo "1. ./quick_fix.sh (этот скрипт уже выполнен)"
echo "2. ./test_build.sh"
echo "3. ./run_docker.sh start"