#!/bin/bash

# Скрипт автоматической установки и настройки сервиса Stenogramma
# Версия: 1.0.0

set -e  # Остановка при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
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
    echo "█           🎵 STENOGRAMMA SETUP SCRIPT 🎵            █"
    echo "█                                                      █"
    echo "████████████████████████████████████████████████████████"
    echo -e "${NC}"
}

# Проверка операционной системы
check_os() {
    print_info "Проверка операционной системы..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        print_success "Обнаружена Linux система"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        print_success "Обнаружена macOS система"
    else
        print_error "Неподдерживаемая операционная система: $OSTYPE"
        exit 1
    fi
}

# Проверка Python
check_python() {
    print_info "Проверка Python..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
        print_success "Python найден: версия $PYTHON_VERSION"
        
        # Проверка версии Python (минимум 3.8)
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
        
        if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 8 ]; then
            print_success "Версия Python подходящая (>=3.8)"
        else
            print_error "Требуется Python 3.8 или выше. Текущая версия: $PYTHON_VERSION"
            exit 1
        fi
    else
        print_error "Python3 не найден. Установите Python 3.8 или выше"
        exit 1
    fi
}

# Проверка pip
check_pip() {
    print_info "Проверка pip..."
    
    if command -v pip3 &> /dev/null; then
        print_success "pip3 найден"
    else
        print_warning "pip3 не найден, попытка установки..."
        if [[ "$OS" == "linux" ]]; then
            sudo apt-get update && sudo apt-get install -y python3-pip
        elif [[ "$OS" == "macos" ]]; then
            curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
            python3 get-pip.py
            rm get-pip.py
        fi
    fi
}

# Установка системных зависимостей
install_system_deps() {
    print_info "Установка системных зависимостей..."
    
    if [[ "$OS" == "linux" ]]; then
        print_info "Обновление пакетов..."
        sudo apt-get update
        
        print_info "Установка системных пакетов..."
        sudo apt-get install -y \
            build-essential \
            python3-dev \
            ffmpeg \
            curl \
            git
            
        print_success "Системные зависимости установлены"
        
    elif [[ "$OS" == "macos" ]]; then
        if command -v brew &> /dev/null; then
            print_info "Установка через Homebrew..."
            brew install ffmpeg
            print_success "FFmpeg установлен через Homebrew"
        else
            print_warning "Homebrew не найден. Установите FFmpeg вручную"
        fi
    fi
}

# Создание виртуального окружения
create_venv() {
    print_info "Создание виртуального окружения..."
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        print_success "Виртуальное окружение создано"
    else
        print_warning "Виртуальное окружение уже существует"
    fi
    
    print_info "Активация виртуального окружения..."
    source venv/bin/activate
    
    print_info "Обновление pip..."
    pip install --upgrade pip
}

# Установка Python зависимостей
install_python_deps() {
    print_info "Установка Python зависимостей..."
    
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        print_success "Серверные зависимости установлены"
    else
        print_error "Файл requirements.txt не найден"
        exit 1
    fi
    
    if [ -f "requirements-client.txt" ]; then
        pip install -r requirements-client.txt
        print_success "Клиентские зависимости установлены"
    else
        print_warning "Файл requirements-client.txt не найден"
    fi
}

# Генерация ключей
generate_keys() {
    print_info "Генерация криптографических ключей..."
    
    if [ -f ".env" ]; then
        print_warning "Файл .env уже существует"
        read -p "Перегенерировать ключи? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Использование существующих ключей"
            return
        fi
    fi
    
    python3 generate_keys.py
    print_success "Ключи сгенерированы и сохранены в .env"
}

# Создание директорий
create_directories() {
    print_info "Создание необходимых директорий..."
    
    mkdir -p temp
    mkdir -p logs
    
    print_success "Директории созданы"
}

# Проверка GPU
check_gpu() {
    print_info "Проверка поддержки GPU..."
    
    if command -v nvidia-smi &> /dev/null; then
        GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1)
        print_success "NVIDIA GPU обнаружен: $GPU_INFO"
        
        # Проверка CUDA
        if python3 -c "import torch; print('CUDA доступен:', torch.cuda.is_available())" 2>/dev/null; then
            print_success "CUDA настроен корректно"
        else
            print_warning "CUDA не настроен, будет использоваться CPU (медленнее)"
        fi
    else
        print_warning "NVIDIA GPU не обнаружен, будет использоваться CPU"
    fi
}

# Проверка установки
test_installation() {
    print_info "Проверка установки..."
    
    if python3 test_crypto.py; then
        print_success "Криптографические функции работают"
    else
        print_error "Ошибка в криптографических функциях"
        exit 1
    fi
    
    print_success "Установка проверена успешно"
}

# Настройка Docker (опционально)
setup_docker() {
    print_info "Проверка Docker..."
    
    if command -v docker &> /dev/null; then
        print_success "Docker найден"
        
        if command -v docker-compose &> /dev/null; then
            print_success "Docker Compose найден"
            
            read -p "Построить Docker образ? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Построение Docker образа..."
                docker build -t stenogramma .
                print_success "Docker образ построен"
            fi
        else
            print_warning "Docker Compose не найден"
        fi
    else
        print_warning "Docker не найден. Для использования Docker установите его отдельно."
    fi
}

# Вывод инструкций
print_instructions() {
    print_info "Установка завершена!"
    echo
    echo -e "${GREEN}🚀 Инструкции по запуску:${NC}"
    echo
    echo "1. Активируйте виртуальное окружение:"
    echo "   source venv/bin/activate"
    echo
    echo "2. Запустите сервер:"
    echo "   uvicorn app:app --host 0.0.0.0 --port 8000"
    echo
    echo "3. Используйте клиент для обработки аудио:"
    echo "   python3 client.py your_audio.wav -o transcript.txt"
    echo
    echo -e "${BLUE}🐳 Альтернативный запуск через Docker:${NC}"
    echo "   docker-compose up -d"
    echo
    echo -e "${YELLOW}📋 Полезные команды:${NC}"
    echo "   python3 health_check.py    # Проверка системы"
    echo "   python3 generate_keys.py   # Перегенерация ключей"
    echo "   python3 test_crypto.py     # Тест шифрования"
    echo
    echo -e "${RED}⚠️  Важные замечания:${NC}"
    echo "   • Не передавайте файл .env третьим лицам"
    echo "   • Сделайте резервную копию ключей"
    echo "   • Для продакшена используйте HTTPS"
    echo "   • Поддерживаются только .wav файлы"
}

# Основная функция
main() {
    print_header
    
    print_info "Начало установки Stenogramma..."
    echo
    
    # Проверки системы
    check_os
    check_python
    check_pip
    
    # Установка зависимостей
    install_system_deps
    create_venv
    install_python_deps
    
    # Настройка
    generate_keys
    create_directories
    check_gpu
    
    # Тестирование
    test_installation
    
    # Docker (опционально)
    setup_docker
    
    # Финальные инструкции
    echo
    print_instructions
    
    print_success "Установка завершена успешно! 🎉"
}

# Проверка запуска от root
if [ "$EUID" -eq 0 ]; then
    print_error "Не запускайте этот скрипт от имени root!"
    print_info "Используйте обычного пользователя. sudo будет запрошен при необходимости."
    exit 1
fi

# Проверка наличия основных файлов
if [ ! -f "app.py" ] || [ ! -f "crypto_utils.py" ]; then
    print_error "Запустите скрипт из корневой директории проекта Stenogramma"
    exit 1
fi

# Запуск основной функции
main