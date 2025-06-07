#!/bin/bash

# Простой тест готовности системы Stenogramma
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
    echo "█         🧪 STENOGRAMMA SYSTEM TEST 🧪              █"
    echo "█                                                      █"
    echo "████████████████████████████████████████████████████████"
    echo -e "${NC}"
}

# Быстрая проверка системы
quick_check() {
    print_header
    
    print_info "Быстрая проверка системы..."
    echo
    
    # Docker
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker: $DOCKER_VERSION"
    else
        print_error "Docker не работает"
        return 1
    fi
    
    # GPU
    if command -v nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        print_success "GPU: $GPU_NAME"
        
        # Тест NVIDIA Docker
        if timeout 15 docker run --rm --gpus all nvidia/cuda:12.9.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
            print_success "NVIDIA Docker: работает"
        else
            print_warning "NVIDIA Docker: не настроен"
        fi
    else
        print_warning "GPU: не обнаружен"
    fi
    
    # Образы
    if docker images stenogramma:latest --format 'table {{.Repository}}:{{.Tag}}' 2>/dev/null | grep -q stenogramma; then
        print_success "GPU образ: найден"
    else
        print_warning "GPU образ: не найден"
    fi
    
    if docker images stenogramma-cpu:latest --format 'table {{.Repository}}:{{.Tag}}' 2>/dev/null | grep -q stenogramma; then
        print_success "CPU образ: найден"
    else
        print_warning "CPU образ: не найден"
    fi
    
    # .env файл
    if [ -f ".env" ]; then
        if grep -q "SECRET_ENDPOINT=" .env && grep -q "KEY_DECRYPT=" .env && grep -q "KEY_ENCRYPT=" .env; then
            print_success ".env файл: настроен"
        else
            print_warning ".env файл: неполный"
        fi
    else
        print_error ".env файл: не найден"
    fi
    
    # Контейнер
    if docker ps --filter name=stenogramma --format 'table {{.Names}}' 2>/dev/null | grep -q stenogramma; then
        print_success "Контейнер: запущен"
        
        # API доступность
        if curl -s -f http://localhost:8000/endpoint_info &> /dev/null; then
            print_success "API: доступен"
        else
            print_warning "API: недоступен"
        fi
    else
        print_warning "Контейнер: не запущен"
    fi
    
    echo
    print_info "Проверка завершена"
    
    # Рекомендации
    echo
    print_info "Рекомендации:"
    
    if ! docker images stenogramma:latest --format 'table {{.Repository}}:{{.Tag}}' 2>/dev/null | grep -q stenogramma && \
       ! docker images stenogramma-cpu:latest --format 'table {{.Repository}}:{{.Tag}}' 2>/dev/null | grep -q stenogramma; then
        echo "   1. Соберите образ: ./build_docker.sh"
    fi
    
    if [ ! -f ".env" ]; then
        echo "   2. Создайте ключи: python3 generate_keys.py"
    fi
    
    if ! docker ps --filter name=stenogramma --format 'table {{.Names}}' 2>/dev/null | grep -q stenogramma; then
        echo "   3. Запустите сервис: ./run_docker.sh start"
    fi
    
    echo "   4. Протестируйте: python3 client.py your_audio.wav"
}

# Основная функция
main() {
    quick_check
}

# Проверка, что скрипт запущен из правильной директории
if [ ! -f "app.py" ] || [ ! -f "crypto_utils.py" ]; then
    print_error "Запустите скрипт из корневой директории проекта Stenogramma"
    exit 1
fi

main