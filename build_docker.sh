#!/bin/bash

# Скрипт сборки Docker образа Stenogramma с автоматическим выбором GPU/CPU
# Версия: 2.0.0

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
    echo "█         🐳 STENOGRAMMA DOCKER BUILD SCRIPT         █"
    echo "█                  v2.0.0 AUTO-SELECT                █"
    echo "████████████████████████████████████████████████████████"
    echo -e "${NC}"
}

show_help() {
    echo "Использование: $0 [ОПЦИИ]"
    echo
    echo "ОПЦИИ:"
    echo "  --gpu           Принудительно использовать GPU образ"
    echo "  --cpu           Принудительно использовать CPU образ"
    echo "  --stable        Использовать стабильную версию (Dockerfile.stable)"
    echo "  --no-cache      Сборка без кэша"
    echo "  --tag TAG       Пользовательский тег образа"
    echo "  --test          Только тестирование после сборки"
    echo "  -h, --help      Показать эту справку"
    echo
    echo "Примеры:"
    echo "  $0                    # Автоматический выбор GPU/CPU"
    echo "  $0 --cpu             # Принудительно CPU версия"
    echo "  $0 --stable          # Стабильная версия с максимальной совместимостью"
    echo "  $0 --gpu --no-cache  # GPU версия без кэша"
}

# Выбор Dockerfile
select_dockerfile() {
    if [ "$FORCE_STABLE" = true ]; then
        if [ ! -f "Dockerfile.stable" ]; then
            print_error "Dockerfile.stable не найден!"
            exit 1
        fi
        DOCKERFILE="Dockerfile.stable"
        BUILD_TYPE="STABLE"
        IMAGE_SUFFIX="-stable"
    elif [ "$FORCE_GPU" = true ]; then
        if [ ! -f "Dockerfile" ]; then
            print_error "Dockerfile не найден!"
            exit 1
        fi
        DOCKERFILE="Dockerfile"
        BUILD_TYPE="GPU"
        IMAGE_SUFFIX=""
    elif [ "$FORCE_CPU" = true ]; then
        if [ ! -f "Dockerfile.cpu" ]; then
            print_error "Dockerfile.cpu не найден!"
            exit 1
        fi
        DOCKERFILE="Dockerfile.cpu"
        BUILD_TYPE="CPU"
        IMAGE_SUFFIX="-cpu"
    else
        # Автоматический выбор
        if check_nvidia_docker; then
            if [ -f "Dockerfile" ]; then
                DOCKERFILE="Dockerfile"
                BUILD_TYPE="GPU"
                IMAGE_SUFFIX=""
                print_success "Выбран GPU образ (автоматически)"
            else
                print_warning "Dockerfile не найден, переключение на CPU"
                DOCKERFILE="Dockerfile.cpu"
                BUILD_TYPE="CPU"
                IMAGE_SUFFIX="-cpu"
            fi
        else
            if [ -f "Dockerfile.cpu" ]; then
                DOCKERFILE="Dockerfile.cpu"
                BUILD_TYPE="CPU"
                IMAGE_SUFFIX="-cpu"
                print_success "Выбран CPU образ (автоматически)"
            else
                print_error "Ни один Dockerfile не найден!"
                exit 1
            fi
        fi
    fi
    
    print_info "Используется: $DOCKERFILE для $BUILD_TYPE сборки"
}

# Проверка Docker
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
    
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    print_success "Docker готов к работе (версия: $DOCKER_VERSION)"
}

# Проверка NVIDIA Docker
check_nvidia_docker() {
    print_info "Проверка NVIDIA Docker поддержки..."
    
    # Проверка nvidia-smi
    if ! command -v nvidia-smi &> /dev/null; then
        print_warning "nvidia-smi не найден"
        return 1
    fi
    
    # Проверка NVIDIA Container Runtime
    if ! docker info 2>/dev/null | grep -q nvidia; then
        print_warning "NVIDIA Container Runtime не настроен"
        return 1
    fi
    
    # Тест запуска NVIDIA контейнера
    if timeout 30 docker run --rm --gpus all nvidia/cuda:12.9.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
        print_success "NVIDIA Docker поддержка работает"
        return 0
    else
        print_warning "NVIDIA Docker тест не прошел"
        return 1
    fi
}

# Проверка файлов проекта
check_project_files() {
    print_info "Проверка файлов проекта..."
    
    required_files=("app.py" "crypto_utils.py" "requirements.txt")
    missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -ne 0 ]; then
        print_error "Отсутствуют файлы: ${missing_files[*]}"
        echo "Запустите скрипт из корневой директории проекта"
        exit 1
    fi
    
    print_success "Все необходимые файлы найдены"
}

# Выбор Dockerfile
select_dockerfile() {
    if [ "$FORCE_GPU" = true ]; then
        if [ ! -f "Dockerfile" ]; then
            print_error "Dockerfile не найден!"
            exit 1
        fi
        DOCKERFILE="Dockerfile"
        BUILD_TYPE="GPU"
        IMAGE_SUFFIX=""
    elif [ "$FORCE_CPU" = true ]; then
        if [ ! -f "Dockerfile.cpu" ]; then
            print_error "Dockerfile.cpu не найден!"
            exit 1
        fi
        DOCKERFILE="Dockerfile.cpu"
        BUILD_TYPE="CPU"
        IMAGE_SUFFIX="-cpu"
    else
        # Автоматический выбор
        if check_nvidia_docker; then
            if [ -f "Dockerfile" ]; then
                DOCKERFILE="Dockerfile"
                BUILD_TYPE="GPU"
                IMAGE_SUFFIX=""
                print_success "Выбран GPU образ (автоматически)"
            else
                print_warning "Dockerfile не найден, переключение на CPU"
                DOCKERFILE="Dockerfile.cpu"
                BUILD_TYPE="CPU"
                IMAGE_SUFFIX="-cpu"
            fi
        else
            if [ -f "Dockerfile.cpu" ]; then
                DOCKERFILE="Dockerfile.cpu"
                BUILD_TYPE="CPU"
                IMAGE_SUFFIX="-cpu"
                print_success "Выбран CPU образ (автоматически)"
            else
                print_error "Ни один Dockerfile не найден!"
                exit 1
            fi
        fi
    fi
    
    print_info "Используется: $DOCKERFILE для $BUILD_TYPE сборки"
}

# Сборка образа
build_image() {
    print_info "Сборка Docker образа..."
    
    IMAGE_NAME="stenogramma${IMAGE_SUFFIX}"
    IMAGE_TAG="${CUSTOM_TAG:-latest}"
    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
    
    print_info "Имя образа: $FULL_IMAGE_NAME"
    print_info "Тип сборки: $BUILD_TYPE"
    
    # Формирование команды сборки
    BUILD_CMD="docker build --progress=plain"
    
    if [ "$NO_CACHE" = true ]; then
        BUILD_CMD="$BUILD_CMD --no-cache"
    fi
    
    BUILD_CMD="$BUILD_CMD -t $FULL_IMAGE_NAME -f $DOCKERFILE ."
    
    print_info "Команда сборки: $BUILD_CMD"
    echo
    
    # Запуск сборки
    if eval "$BUILD_CMD"; then
        print_success "Образ успешно собран: $FULL_IMAGE_NAME"
    else
        print_error "Ошибка сборки образа"
        exit 1
    fi
    
    # Проверка размера образа
    IMAGE_SIZE=$(docker images "$FULL_IMAGE_NAME" --format "table {{.Size}}" | tail -n 1)
    print_info "Размер образа: $IMAGE_SIZE"
}

# Тестирование образа
test_image() {
    print_info "Тестирование образа..."
    
    # Создание тестовых переменных окружения
    TEST_ENDPOINT=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))" 2>/dev/null || echo "test_endpoint_$(date +%s)")
    TEST_KEY_DECRYPT=$(python3 -c "import secrets; print(secrets.token_bytes(32).hex())" 2>/dev/null || echo "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
    TEST_KEY_ENCRYPT=$(python3 -c "import secrets; print(secrets.token_bytes(32).hex())" 2>/dev/null || echo "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210")
    
    DOCKER_RUN_CMD="docker run -d"
    DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e SECRET_ENDPOINT=$TEST_ENDPOINT"
    DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e KEY_DECRYPT=$TEST_KEY_DECRYPT"
    DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e KEY_ENCRYPT=$TEST_KEY_ENCRYPT"
    DOCKER_RUN_CMD="$DOCKER_RUN_CMD -p 18000:8000"
    DOCKER_RUN_CMD="$DOCKER_RUN_CMD --name stenogramma-test"
    
    # Добавление GPU поддержки для тестирования
    if [ "$BUILD_TYPE" = "GPU" ] && [ "$FORCE_CPU" != true ]; then
        DOCKER_RUN_CMD="$DOCKER_RUN_CMD --gpus all"
    fi
    
    DOCKER_RUN_CMD="$DOCKER_RUN_CMD $FULL_IMAGE_NAME"
    
    # Тестовый запуск контейнера
    print_info "Запуск тестового контейнера..."
    if CONTAINER_ID=$(eval "$DOCKER_RUN_CMD"); then
        print_success "Контейнер запущен для тестирования: $CONTAINER_ID"
        
        # Ожидание запуска
        print_info "Ожидание инициализации сервиса..."
        RETRY_COUNT=0
        MAX_RETRIES=12
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            if curl -f http://localhost:18000/endpoint_info &> /dev/null; then
                print_success "Сервис отвечает корректно"
                break
            else
                RETRY_COUNT=$((RETRY_COUNT + 1))
                if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
                    print_warning "Сервис не отвечает после $MAX_RETRIES попыток"
                    docker logs stenogramma-test | tail -20
                else
                    echo -n "."
                    sleep 5
                fi
            fi
        done
        
        # Остановка и удаление тестового контейнера
        docker stop stenogramma-test &> /dev/null || true
        docker rm stenogramma-test &> /dev/null || true
        print_info "Тестовый контейнер удален"
    else
        print_error "Ошибка запуска тестового контейнера"
        exit 1
    fi
}

# Вывод инструкций по использованию
print_usage_instructions() {
    echo
    print_success "🎉 Сборка завершена успешно!"
    echo
    echo -e "${GREEN}📋 Инструкции по запуску:${NC}"
    echo
    echo "1. Создайте файл с переменными окружения:"
    echo "   python3 generate_keys.py          # Для тестирования"
    echo "   python3 generate_production_env.py # Для продакшена"
    echo
    echo "2. Запуск контейнера:"
    
    if [ "$BUILD_TYPE" = "GPU" ]; then
        echo -e "${BLUE}   # С GPU поддержкой:${NC}"
        echo "   docker run -d \\"
        echo "     --name stenogramma \\"
        echo "     --gpus all \\"
        echo "     -p 8000:8000 \\"
        echo "     --env-file .env \\"
        echo "     --restart unless-stopped \\"
        echo "     $FULL_IMAGE_NAME"
        echo
        echo -e "${YELLOW}   # Альтернативно через run_docker.sh:${NC}"
        echo "   ./run_docker.sh start"
    else
        echo -e "${YELLOW}   # CPU режим:${NC}"
        echo "   docker run -d \\"
        echo "     --name stenogramma \\"
        echo "     -p 8000:8000 \\"
        echo "     --env-file .env \\"
        echo "     --restart unless-stopped \\"
        echo "     $FULL_IMAGE_NAME"
        echo
        echo -e "${YELLOW}   # Альтернативно через run_docker.sh:${NC}"
        echo "   ./run_docker.sh -i $FULL_IMAGE_NAME start"
    fi
    
    echo
    echo "3. Проверка статуса:"
    echo "   docker logs stenogramma"
    echo "   curl http://localhost:8000/endpoint_info"
    echo
    echo "4. Использование клиента:"
    echo "   pip install -r requirements-client.txt"
    echo "   python3 client.py your_audio.wav"
    echo
    echo -e "${RED}⚠️  Важные замечания:${NC}"
    echo "   • Образ: $FULL_IMAGE_NAME ($BUILD_TYPE режим)"
    echo "   • Размер: $IMAGE_SIZE"
    if [ "$BUILD_TYPE" = "CPU" ]; then
        echo "   • CPU режим: обработка будет медленнее"
        echo "   • Для GPU сборки: $0 --gpu или $0 --stable"
    elif [ "$BUILD_TYPE" = "STABLE" ]; then
        echo "   • STABLE режим: максимальная совместимость с fallback"
        echo "   • Для чистого GPU: $0 --gpu"
        echo "   • Для CPU только: $0 --cpu"
    else
        echo "   • GPU режим: требует NVIDIA драйверы"
        echo "   • Для стабильной версии: $0 --stable"
        echo "   • Для CPU сборки: $0 --cpu"
    fi
    echo "   • Не забудьте настроить .env файл"
}

# Парсинг аргументов
FORCE_GPU=false
FORCE_CPU=false
FORCE_STABLE=false
NO_CACHE=false
CUSTOM_TAG=""
TEST_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cpu)
            FORCE_CPU=true
            shift
            ;;
        --stable)
            FORCE_STABLE=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --stable)
            FORCE_STABLE=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --tag)
            CUSTOM_TAG="$2"
            shift 2
            ;;
        --test)
            TEST_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Неизвестная опция: $1"
            show_help
            exit 1
            ;;
    esac
done

# Проверка конфликтующих опций
OPTION_COUNT=0
[ "$FORCE_GPU" = true ] && OPTION_COUNT=$((OPTION_COUNT + 1))
[ "$FORCE_CPU" = true ] && OPTION_COUNT=$((OPTION_COUNT + 1))
[ "$FORCE_STABLE" = true ] && OPTION_COUNT=$((OPTION_COUNT + 1))

if [ $OPTION_COUNT -gt 1 ]; then
    print_error "Нельзя одновременно указать --gpu, --cpu и --stable"
    exit 1
fi

# Основная логика
main() {
    print_header
    
    check_docker
    check_project_files
    select_dockerfile
    
    if [ "$TEST_ONLY" != true ]; then
        build_image
    fi
    
    test_image
    print_usage_instructions
    
    echo
    print_success "Готово! Используйте образ: $FULL_IMAGE_NAME"
}

# Проверка, что скрипт запущен из правильной директории
if [ ! -f "app.py" ] || [ ! -f "crypto_utils.py" ]; then
    print_error "Запустите скрипт из корневой директории проекта Stenogramma"
    exit 1
fi

# Запуск
main