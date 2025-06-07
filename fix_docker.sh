#!/bin/bash

# Скрипт автоматического исправления проблем с Docker образами Stenogramma
# Версия: 1.0.0

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "████████████████████████████████████████████████████████"
    echo "█                                                      █"
    echo "█         🔧 STENOGRAMMA DOCKER FIX TOOL 🔧          █"
    echo "█                                                      █"
    echo "████████████████████████████████████████████████████████"
    echo -e "${NC}"
}

# Список CUDA образов для тестирования (от новых к старым)
CUDA_IMAGES=(
    "nvidia/cuda:12.9.0-runtime-ubuntu22.04"
    "nvidia/cuda:12.9.0-base-ubuntu22.04"
    "nvidia/cuda:12.2-runtime-ubuntu22.04"
    "nvidia/cuda:12.1-runtime-ubuntu22.04"
    "nvidia/cuda:12.0-runtime-ubuntu22.04"
    "nvidia/cuda:11.8-runtime-ubuntu22.04"
    "nvidia/cuda:11.7-runtime-ubuntu22.04"
    "ubuntu:22.04"
)

# Соответствующие PyTorch индексы
declare -A PYTORCH_INDICES=(
    ["nvidia/cuda:12.9.0-runtime-ubuntu22.04"]="cu124"
    ["nvidia/cuda:12.9.0-base-ubuntu22.04"]="cu124"
    ["nvidia/cuda:12.2-runtime-ubuntu22.04"]="cu121"
    ["nvidia/cuda:12.1-runtime-ubuntu22.04"]="cu121"
    ["nvidia/cuda:12.0-runtime-ubuntu22.04"]="cu118"
    ["nvidia/cuda:11.8-runtime-ubuntu22.04"]="cu118"
    ["nvidia/cuda:11.7-runtime-ubuntu22.04"]="cu117"
    ["ubuntu:22.04"]="cpu"
)

check_docker() {
    print_info "Проверка Docker..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен!"
        echo "Установите Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon не запущен!"
        echo "Запустите Docker daemon"
        exit 1
    fi
    
    print_success "Docker работает"
}

test_base_image() {
    local image=$1
    print_info "Тестирование образа: $image"
    
    if timeout 30 docker pull "$image" &> /dev/null; then
        print_success "Образ $image доступен"
        return 0
    else
        print_warning "Образ $image недоступен"
        return 1
    fi
}

find_working_cuda_image() {
    print_info "Поиск рабочего CUDA образа..."
    
    for image in "${CUDA_IMAGES[@]}"; do
        if test_base_image "$image"; then
            WORKING_IMAGE="$image"
            PYTORCH_INDEX="${PYTORCH_INDICES[$image]}"
            
            if [[ "$image" == *"nvidia/cuda"* ]]; then
                IS_GPU_IMAGE=true
                print_success "Найден рабочий GPU образ: $image"
            else
                IS_GPU_IMAGE=false
                print_success "Fallback на CPU образ: $image"
            fi
            
            return 0
        fi
    done
    
    print_error "Не найдено ни одного рабочего образа!"
    return 1
}

backup_dockerfile() {
    local dockerfile=$1
    if [ -f "$dockerfile" ]; then
        local backup_name="${dockerfile}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$dockerfile" "$backup_name"
        print_info "Создана резервная копия: $backup_name"
    fi
}

create_fixed_dockerfile() {
    local dockerfile=$1
    local base_image=$2
    local pytorch_index=$3
    local is_gpu=$4
    
    print_info "Создание исправленного $dockerfile..."
    
    backup_dockerfile "$dockerfile"
    
    cat > "$dockerfile" << EOF
FROM $base_image

# Отключение интерактивных запросов во время сборки
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \\
    python3.10 \\
    python3.10-dev \\
    python3-pip \\
    python3.10-venv \\
    ffmpeg \\
    libsndfile1 \\
    curl \\
    wget \\
    git \\
    build-essential \\
    pkg-config \\
    libffi-dev \\
    && rm -rf /var/lib/apt/lists/* \\
    && apt-get clean

# Создание символической ссылки для python
RUN ln -sf /usr/bin/python3.10 /usr/bin/python3 \\
    && ln -sf /usr/bin/python3.10 /usr/bin/python

# Обновление pip
RUN python3 -m pip install --upgrade pip setuptools wheel

# Создание рабочей директории
WORKDIR /app

# Создание пользователя для безопасности
RUN useradd -m -u 1000 -s /bin/bash appuser \\
    && mkdir -p /app/temp /app/logs \\
    && chown -R appuser:appuser /app

# Копирование requirements и установка Python зависимостей
COPY requirements.txt /app/
EOF

    if [ "$pytorch_index" = "cpu" ]; then
        cat >> "$dockerfile" << EOF
RUN pip3 install --no-cache-dir --upgrade pip \\
    && pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu \\
    && pip3 install --no-cache-dir -r requirements.txt
EOF
    else
        cat >> "$dockerfile" << EOF
RUN pip3 install --no-cache-dir --upgrade pip \\
    && pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/$pytorch_index \\
    && pip3 install --no-cache-dir -r requirements.txt
EOF
    fi

    cat >> "$dockerfile" << EOF

# Копирование кода приложения
COPY app.py crypto_utils.py /app/
RUN chown -R appuser:appuser /app

# Переключение на пользователя appuser
USER appuser

# Предзагрузка модели Whisper
RUN python3 -c "from faster_whisper import WhisperModel; WhisperModel('large-v3', device='cpu', compute_type='int8')" || true

# Создание точки входа
RUN echo '#!/bin/bash\\n\\
set -e\\n\\
\\n\\
# Проверка переменных окружения\\n\\
if [ -z "\$SECRET_ENDPOINT" ] || [ -z "\$KEY_DECRYPT" ] || [ -z "\$KEY_ENCRYPT" ]; then\\n\\
    echo "❌ Ошибка: Не настроены переменные окружения!"\\n\\
    echo "Требуются: SECRET_ENDPOINT, KEY_DECRYPT, KEY_ENCRYPT"\\n\\
    exit 1\\n\\
fi\\n\\
\\n\\
EOF

    if [ "$is_gpu" = true ]; then
        cat >> "$dockerfile" << EOF
# Проверка GPU\\n\\
if command -v nvidia-smi &> /dev/null; then\\n\\
    echo "🎮 GPU Information:"\\n\\
    nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader,nounits | head -1 || echo "GPU info unavailable"\\n\\
else\\n\\
    echo "⚠️  GPU не обнаружен, используется CPU"\\n\\
fi\\n\\
EOF
    else
        cat >> "$dockerfile" << EOF
echo "🖥️  Запуск в CPU режиме"\\n\\
EOF
    fi

    cat >> "$dockerfile" << EOF
\\n\\
# Создание необходимых директорий\\n\\
mkdir -p /app/temp /app/logs\\n\\
\\n\\
# Запуск приложения\\n\\
echo "🚀 Запуск Stenogramma на порту 8000..."\\n\\
exec uvicorn app:app --host 0.0.0.0 --port 8000 --workers 1' > /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \\
    CMD curl -f http://localhost:8000/endpoint_info || exit 1

# Экспозиция порта
EXPOSE 8000

# Запуск
ENTRYPOINT ["/app/entrypoint.sh"]
EOF

    print_success "Создан исправленный $dockerfile с образом $base_image"
}

fix_app_py() {
    print_info "Проверка app.py на совместимость с CPU/GPU..."
    
    if [ -f "app.py" ]; then
        # Создание резервной копии
        backup_dockerfile "app.py"
        
        # Исправление device detection в app.py
        sed -i 's/device="cuda"/device="cuda" if torch.cuda.is_available() else "cpu"/' app.py || true
        sed -i 's/compute_type="float16"/compute_type="float16" if torch.cuda.is_available() else "int8"/' app.py || true
        
        print_success "app.py обновлен для автоматического определения устройства"
    fi
}

test_fixed_image() {
    local dockerfile=$1
    print_info "Тестирование исправленного Dockerfile..."
    
    # Попытка сборки с минимальным кэшем
    if timeout 300 docker build -f "$dockerfile" --no-cache -t stenogramma-test . &> build.log; then
        print_success "Сборка тестового образа успешна"
        
        # Очистка тестового образа
        docker rmi stenogramma-test &> /dev/null || true
        rm -f build.log
        return 0
    else
        print_error "Ошибка сборки тестового образа"
        echo "Логи сборки:"
        tail -20 build.log 2>/dev/null || echo "Логи недоступны"
        rm -f build.log
        return 1
    fi
}

show_fix_summary() {
    echo
    print_success "🎉 Исправление завершено!"
    echo
    echo -e "${GREEN}📋 Что было исправлено:${NC}"
    echo "   • Базовый образ: $WORKING_IMAGE"
    echo "   • PyTorch индекс: $PYTORCH_INDEX"
    
    if [ "$IS_GPU_IMAGE" = true ]; then
        echo "   • Тип: GPU образ"
        echo "   • Dockerfile: обновлен для GPU поддержки"
        if [ -f "Dockerfile.cpu" ]; then
            echo "   • Dockerfile.cpu: создан как fallback"
        fi
    else
        echo "   • Тип: CPU fallback образ"
        echo "   • Dockerfile.cpu: создан для CPU режима"
    fi
    
    echo
    echo -e "${BLUE}🚀 Следующие шаги:${NC}"
    echo "1. Проверьте изменения:"
    echo "   git diff Dockerfile*"
    echo
    echo "2. Запустите сборку:"
    if [ "$IS_GPU_IMAGE" = true ]; then
        echo "   ./build_docker.sh --gpu"
    else
        echo "   ./build_docker.sh --cpu"
    fi
    echo
    echo "3. При проблемах используйте альтернативный образ:"
    if [ "$IS_GPU_IMAGE" = true ]; then
        echo "   ./build_docker.sh --cpu"
    else
        echo "   # Исправьте NVIDIA настройки и попробуйте:"
        echo "   ./build_docker.sh --gpu"
    fi
    echo
    echo -e "${RED}⚠️  Важно:${NC}"
    echo "   • Резервные копии созданы с расширением .backup.*"
    echo "   • Проверьте совместимость PyTorch версии с вашим CUDA"
    echo "   • Для продакшена рекомендуется GPU образ"
}

main() {
    print_header
    
    print_info "Автоматическое исправление проблем с Docker образами..."
    echo
    
    check_docker
    
    if ! find_working_cuda_image; then
        print_error "Не удалось найти рабочий образ!"
        exit 1
    fi
    
    # Исправление основного Dockerfile
    if [ "$IS_GPU_IMAGE" = true ]; then
        create_fixed_dockerfile "Dockerfile" "$WORKING_IMAGE" "$PYTORCH_INDEX" true
        
        # Создание CPU fallback
        for cpu_image in "ubuntu:22.04" "ubuntu:20.04"; do
            if test_base_image "$cpu_image"; then
                create_fixed_dockerfile "Dockerfile.cpu" "$cpu_image" "cpu" false
                break
            fi
        done
    else
        # Только CPU версия
        create_fixed_dockerfile "Dockerfile.cpu" "$WORKING_IMAGE" "$PYTORCH_INDEX" false
        
        # Удаление старого GPU Dockerfile если он некорректный
        if [ -f "Dockerfile" ]; then
            backup_dockerfile "Dockerfile"
            rm -f "Dockerfile"
            print_info "Удален некорректный GPU Dockerfile"
        fi
    fi
    
    # Исправление app.py
    fix_app_py
    
    # Тест исправленного образа
    if [ "$IS_GPU_IMAGE" = true ] && [ -f "Dockerfile" ]; then
        test_fixed_image "Dockerfile"
    elif [ -f "Dockerfile.cpu" ]; then
        test_fixed_image "Dockerfile.cpu"
    fi
    
    show_fix_summary
}

# Проверка запуска из правильной директории
if [ ! -f "app.py" ] || [ ! -f "crypto_utils.py" ]; then
    print_error "Запустите скрипт из корневой директории проекта Stenogramma"
    exit 1
fi

main