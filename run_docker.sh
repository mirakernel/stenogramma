#!/bin/bash

# Скрипт для упрощенного запуска Stenogramma Docker контейнера
# Версия: 1.0.0

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Настройки по умолчанию
CONTAINER_NAME="stenogramma"
IMAGE_NAME=""  # Будет определен автоматически
PORT="8000"
ENV_FILE=".env"

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
    echo "█         🚀 STENOGRAMMA DOCKER RUNNER 🚀            █"
    echo "█                                                      █"
    echo "████████████████████████████████████████████████████████"
    echo -e "${NC}"
}

show_help() {
    echo "Использование: $0 [ОПЦИИ] [КОМАНДА]"
    echo
    echo "КОМАНДЫ:"
    echo "  start       Запуск контейнера (по умолчанию)"
    echo "  stop        Остановка контейнера"
    echo "  restart     Перезапуск контейнера"
    echo "  status      Проверка статуса"
    echo "  logs        Показать логи"
    echo "  shell       Подключиться к контейнеру"
    echo "  remove      Удалить контейнер"
    echo
    echo "ОПЦИИ:"
    echo "  -n, --name NAME     Имя контейнера (по умолчанию: stenogramma)"
    echo "  -p, --port PORT     Порт для привязки (по умолчанию: 8000)"
    echo "  -e, --env-file FILE Файл с переменными окружения (по умолчанию: .env)"
    echo "  -i, --image IMAGE   Имя Docker образа (автоопределение: stenogramma:latest или stenogramma-cpu:latest)"
    echo "  --gpu               Принудительно использовать GPU образ"
    echo "  --cpu               Принудительно использовать CPU образ"
    echo "  --detach            Запуск в фоновом режиме (по умолчанию)"
    echo "  --interactive       Интерактивный запуск"
    echo "  -h, --help          Показать эту справку"
    echo
    echo "Примеры:"
    echo "  $0                           # Автоматический выбор GPU/CPU образа"
    echo "  $0 start --cpu               # Принудительно CPU образ"
    echo "  $0 --gpu -p 9000 start       # GPU образ на порту 9000"
    echo "  $0 logs                      # Показать логи"
    echo "  $0 stop                      # Остановить контейнер"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен!"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon не запущен!"
        exit 1
    fi
}

detect_available_images() {
    print_info "Определение доступных образов..."
    
    GPU_IMAGE_AVAILABLE=false
    CPU_IMAGE_AVAILABLE=false
    
    if docker image inspect "stenogramma:latest" &> /dev/null; then
        GPU_IMAGE_AVAILABLE=true
        print_info "Найден GPU образ: stenogramma:latest"
    fi
    
    if docker image inspect "stenogramma-cpu:latest" &> /dev/null; then
        CPU_IMAGE_AVAILABLE=true
        print_info "Найден CPU образ: stenogramma-cpu:latest"
    fi
    
    if [ "$GPU_IMAGE_AVAILABLE" = false ] && [ "$CPU_IMAGE_AVAILABLE" = false ]; then
        print_error "Не найдено ни одного Docker образа!"
        echo "Выполните сборку: ./build_docker.sh"
        exit 1
    fi
}

select_image() {
    if [ -n "$IMAGE_NAME" ]; then
        # Пользователь указал образ вручную
        if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
            print_error "Указанный образ '$IMAGE_NAME' не найден!"
            exit 1
        fi
        print_info "Используется указанный образ: $IMAGE_NAME"
        return
    fi
    
    # Автоматический выбор или принудительный режим
    if [ "$FORCE_GPU" = true ]; then
        if [ "$GPU_IMAGE_AVAILABLE" = true ]; then
            IMAGE_NAME="stenogramma:latest"
            USE_GPU=true
            print_success "Выбран GPU образ (принудительно)"
        else
            print_error "GPU образ не найден! Выполните: ./build_docker.sh --gpu"
            exit 1
        fi
    elif [ "$FORCE_CPU" = true ]; then
        if [ "$CPU_IMAGE_AVAILABLE" = true ]; then
            IMAGE_NAME="stenogramma-cpu:latest"
            USE_GPU=false
            print_success "Выбран CPU образ (принудительно)"
        else
            print_error "CPU образ не найден! Выполните: ./build_docker.sh --cpu"
            exit 1
        fi
    else
        # Автоматический выбор
        if [ "$GPU_IMAGE_AVAILABLE" = true ] && check_gpu_support; then
            IMAGE_NAME="stenogramma:latest"
            USE_GPU=true
            print_success "Выбран GPU образ (автоматически)"
        elif [ "$CPU_IMAGE_AVAILABLE" = true ]; then
            IMAGE_NAME="stenogramma-cpu:latest"
            USE_GPU=false
            print_success "Выбран CPU образ (автоматически)"
        elif [ "$GPU_IMAGE_AVAILABLE" = true ]; then
            IMAGE_NAME="stenogramma:latest"
            USE_GPU=false
            print_warning "GPU недоступен, но используется GPU образ без --gpus"
        else
            print_error "Нет доступных образов!"
            exit 1
        fi
    fi
}

check_image() {
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        print_error "Docker образ '$IMAGE_NAME' не найден!"
        echo "Выполните сборку: ./build_docker.sh"
        exit 1
    fi
}

check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        print_error "Файл переменных окружения '$ENV_FILE' не найден!"
        echo "Создайте файл .env или используйте --env-file для указания другого файла"
        echo "Пример содержимого .env:"
        echo "SECRET_ENDPOINT=your_secret_endpoint_32chars"
        echo "KEY_DECRYPT=your_64_char_hex_key"
        echo "KEY_ENCRYPT=your_64_char_hex_key"
        exit 1
    fi
    
    # Проверка обязательных переменных
    if ! grep -q "SECRET_ENDPOINT=" "$ENV_FILE" || \
       ! grep -q "KEY_DECRYPT=" "$ENV_FILE" || \
       ! grep -q "KEY_ENCRYPT=" "$ENV_FILE"; then
        print_error "В файле '$ENV_FILE' отсутствуют обязательные переменные!"
        print_info "Сгенерируйте ключи: python3 generate_keys.py"
        exit 1
    fi
}

check_gpu_support() {
    if command -v nvidia-smi &> /dev/null; then
        if timeout 10 docker run --rm --gpus all nvidia/cuda:12.9.0-base-ubuntu22.04 nvidia-smi &> /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

start_container() {
    print_info "Запуск контейнера '$CONTAINER_NAME'..."
    
    # Проверка, не запущен ли уже контейнер
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        print_warning "Контейнер '$CONTAINER_NAME' уже запущен"
        return 0
    fi
    
    # Удаление остановленного контейнера с тем же именем
    if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
        print_info "Удаление существующего контейнера..."
        docker rm "$CONTAINER_NAME" > /dev/null
    fi
    
    # Формирование команды запуска
    DOCKER_CMD="docker run"
    
    if [ "$INTERACTIVE" = false ]; then
        DOCKER_CMD="$DOCKER_CMD -d"
    else
        DOCKER_CMD="$DOCKER_CMD -it"
    fi
    
    DOCKER_CMD="$DOCKER_CMD --name $CONTAINER_NAME"
    DOCKER_CMD="$DOCKER_CMD --restart unless-stopped"
    DOCKER_CMD="$DOCKER_CMD -p $PORT:8000"
    DOCKER_CMD="$DOCKER_CMD --env-file $ENV_FILE"
    
    # Добавление GPU поддержки только если это GPU образ и GPU доступен
    if [ "$USE_GPU" = true ] && [[ "$IMAGE_NAME" == *"stenogramma:latest"* ]]; then
        DOCKER_CMD="$DOCKER_CMD --gpus all"
        print_info "Включена GPU поддержка"
    elif [[ "$IMAGE_NAME" == *"stenogramma-cpu"* ]]; then
        print_info "Запуск в CPU режиме"
    fi
    
    DOCKER_CMD="$DOCKER_CMD $IMAGE_NAME"
    
    print_info "Команда запуска: $DOCKER_CMD"
    
    # Запуск контейнера
    if eval "$DOCKER_CMD"; then
        if [ "$INTERACTIVE" = false ]; then
            print_success "Контейнер '$CONTAINER_NAME' запущен в background режиме"
            print_info "Порт: http://localhost:$PORT"
            print_info "Логи: $0 logs"
            print_info "Статус: $0 status"
        fi
    else
        print_error "Ошибка запуска контейнера"
        exit 1
    fi
}

stop_container() {
    print_info "Остановка контейнера '$CONTAINER_NAME'..."
    
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker stop "$CONTAINER_NAME"
        print_success "Контейнер остановлен"
    else
        print_warning "Контейнер '$CONTAINER_NAME' не запущен"
    fi
}

restart_container() {
    stop_container
    sleep 2
    start_container
}

show_status() {
    print_info "Статус контейнера '$CONTAINER_NAME':"
    
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        echo -e "${GREEN}🟢 Запущен${NC}"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" -f name="$CONTAINER_NAME"
        
        # Определение типа образа
        RUNNING_IMAGE=$(docker inspect "$CONTAINER_NAME" --format='{{.Config.Image}}' 2>/dev/null || echo "unknown")
        if [[ "$RUNNING_IMAGE" == *"cpu"* ]]; then
            echo -e "${YELLOW}🖥️  Режим: CPU${NC}"
        else
            echo -e "${GREEN}🎮 Режим: GPU${NC}"
        fi
        
        # Проверка доступности сервиса
        if curl -s -f "http://localhost:$PORT/endpoint_info" > /dev/null 2>&1; then
            echo -e "${GREEN}🌐 Сервис доступен на http://localhost:$PORT${NC}"
        else
            echo -e "${YELLOW}⏳ Сервис еще загружается...${NC}"
        fi
    elif docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
        echo -e "${RED}🔴 Остановлен${NC}"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" -f name="$CONTAINER_NAME"
    else
        echo -e "${YELLOW}⚪ Не существует${NC}"
    fi
}

show_logs() {
    if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
        docker logs -f "$CONTAINER_NAME"
    else
        print_error "Контейнер '$CONTAINER_NAME' не найден"
        exit 1
    fi
}

connect_shell() {
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker exec -it "$CONTAINER_NAME" /bin/bash
    else
        print_error "Контейнер '$CONTAINER_NAME' не запущен"
        exit 1
    fi
}

remove_container() {
    print_info "Удаление контейнера '$CONTAINER_NAME'..."
    
    # Остановка если запущен
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        docker stop "$CONTAINER_NAME"
    fi
    
    # Удаление
    if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
        docker rm "$CONTAINER_NAME"
        print_success "Контейнер удален"
    else
        print_warning "Контейнер '$CONTAINER_NAME' не найден"
    fi
}

# Парсинг аргументов
USE_GPU=true
FORCE_GPU=false
FORCE_CPU=false
INTERACTIVE=false
COMMAND="start"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -e|--env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --gpu)
            FORCE_GPU=true
            shift
            ;;
        --cpu)
            FORCE_CPU=true
            shift
            ;;
        --detach)
            INTERACTIVE=false
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        start|stop|restart|status|logs|shell|remove)
            COMMAND="$1"
            shift
            ;;
        *)
            print_error "Неизвестная опция: $1"
            show_help
            exit 1
            ;;
    esac
done

# Основная логика
main() {
    print_header
    
    check_docker
    
    case $COMMAND in
        start)
            detect_available_images
            select_image
            check_image
            check_env_file
            start_container
            ;;
        stop)
            stop_container
            ;;
        restart)
            detect_available_images
            select_image
            check_image
            check_env_file
            restart_container
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        shell)
            connect_shell
            ;;
        remove)
            remove_container
            ;;
        *)
            print_error "Неизвестная команда: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

main