# 🚀 QUICKSTART - Быстрый старт Stenogramma

## За 5 минут до работающего сервиса

### 1. Клонирование и переход в папку
```bash
git clone <repository-url>
cd stenogramma
```

### 2. Генерация ключей безопасности
```bash
# Для тестирования
python3 generate_keys.py

# Для продакшена
python3 generate_production_env.py
```

### 3. Сборка Docker образа
```bash
# Автоматическая сборка (рекомендуется)
./build_docker.sh

# При ошибках PyTorch/CUDA - быстрое исправление
./quick_fix.sh

# При проблемах с CUDA образами - автоисправление
./fix_docker.sh && ./build_docker.sh

# Принудительно CPU версия
./build_docker.sh --cpu

# Принудительно GPU версия (если доступна)
./build_docker.sh --gpu
```
</edits>

<old_text>
### Ошибки Docker образов
```bash
# "nvidia/cuda:11.8-devel-ubuntu22.04: not found"
./fix_docker.sh

# Автоматическое исправление и пересборка
./fix_docker.sh && ./build_docker.sh

# Принудительная CPU сборка (всегда работает)
./build_docker.sh --cpu

# Очистка всех образов и пересборка
docker system prune -a -f
./fix_docker.sh
./build_docker.sh
```
</edits>

<old_text>
## Решение частых проблем

### Ошибка "Port already in use"
```bash
./run_docker.sh -p 9000 start
```

### Проблемы с GPU
```bash
# Проверка GPU
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.1-base-ubuntu22.04 nvidia-smi

# Запуск без GPU
./run_docker.sh --cpu start
```

### Ошибки Docker образов
```bash
# "nvidia/cuda:11.8-devel-ubuntu22.04: not found"
./fix_docker.sh

# Автоматическое исправление и пересборка
./fix_docker.sh && ./build_docker.sh

# Принудительная CPU сборка (всегда работает)
./build_docker.sh --cpu

# Очистка всех образов и пересборка
docker system prune -a -f
./fix_docker.sh
./build_docker.sh
```

### Проблемы сборки образа
```bash
# Сборка без кэша
./build_docker.sh --no-cache

# Проверка доступных базовых образов
docker search nvidia/cuda | head -10

# Ручная проверка образа
docker pull nvidia/cuda:12.1-runtime-ubuntu22.04
```

### 4. Запуск сервиса
```bash
# С GPU (рекомендуется)
./run_docker.sh start

# Без GPU
./run_docker.sh start --no-gpu
```

### 5. Проверка работы
```bash
./run_docker.sh status
curl http://localhost:8000/endpoint_info
```

### 6. Тестирование транскрибации
```bash
# Установка клиентских зависимостей
pip install -r requirements-client.txt

# Транскрибация аудиофайла
python3 client.py your_audio.wav -o transcript.txt
```

## Готовые команды для копирования

## Полная установка одной командой
```bash
# Стандартная установка
git clone <repository-url> && cd stenogramma && python3 generate_keys.py && ./build_docker.sh && ./run_docker.sh start

# Установка с автоисправлением (при проблемах)
git clone <repository-url> && cd stenogramma && python3 generate_keys.py && ./fix_docker.sh && ./build_docker.sh && ./run_docker.sh start

# Принудительно CPU установка (гарантированно работает)
git clone <repository-url> && cd stenogramma && python3 generate_keys.py && ./build_docker.sh --cpu && ./run_docker.sh --cpu start

# При ошибках Docker образов
git clone <repository-url> && cd stenogramma && python3 generate_keys.py && ./quick_fix.sh && ./run_docker.sh start
```
</edits>

<old_text>
## Быстрая диагностика

```bash
#!/bin/bash
echo "=== STENOGRAMMA DIAGNOSTIC ==="
echo "Docker: $(docker --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'NOT AVAILABLE')"
echo "GPU Image: $(docker images stenogramma:latest --format 'table {{.Repository}}:{{.Tag}}' 2>/dev/null || echo 'NOT BUILT')"
echo "CPU Image: $(docker images stenogramma-cpu:latest --format 'table {{.Repository}}:{{.Tag}}' 2>/dev/null || echo 'NOT BUILT')"
echo "Container: $(docker ps --filter name=stenogramma --format 'table {{.Names}} {{.Status}}' 2>/dev/null || echo 'NOT RUNNING')"
echo "Port 8000: $(curl -s http://localhost:8000/endpoint_info && echo 'OK' || echo 'NOT ACCESSIBLE')"
```

## Устранение проблем "из коробки"

```bash
# Быстрое исправление PyTorch проблем
./quick_fix.sh

# Универсальный фиксер всех проблем
./fix_docker.sh

# Если ничего не работает - полная переустановка
docker system prune -a -f
rm -rf .env Dockerfile*
python3 generate_keys.py
./quick_fix.sh
./run_docker.sh start
```
</edits>

### Проверка всех компонентов
```bash
python3 health_check.py && python3 test_crypto.py && ./run_docker.sh status
```

### Остановка и очистка
```bash
./run_docker.sh stop && ./run_docker.sh remove
```

## Production развертывание

### Генерация production ключей
```bash
python3 generate_production_env.py
```

### Запуск production контейнера
```bash
./build_docker.sh && ./run_docker.sh -e .env start
```

### Мониторинг
```bash
# Логи в реальном времени
./run_docker.sh logs

# Проверка статуса каждые 30 сек
watch -n 30 './run_docker.sh status'
```

## Решение частых проблем

### Ошибка "Port already in use"
```bash
./run_docker.sh -p 9000 start
```

### Проблемы с GPU
```bash
# Проверка GPU
nvidia-smi
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu22.04 nvidia-smi

# Запуск без GPU
./run_docker.sh start --no-gpu
```

### Проблемы с правами
```bash
sudo chown -R $USER:$USER .
chmod +x *.sh
```

### Ошибки ключей
```bash
rm .env
python3 generate_keys.py
./run_docker.sh restart
```

## Полезные алиасы

Добавьте в `~/.bashrc`:

```bash
alias steno-start='cd /path/to/stenogramma && ./run_docker.sh start'
alias steno-stop='cd /path/to/stenogramma && ./run_docker.sh stop'
alias steno-status='cd /path/to/stenogramma && ./run_docker.sh status'
alias steno-logs='cd /path/to/stenogramma && ./run_docker.sh logs'
alias steno-client='cd /path/to/stenogramma && python3 client.py'
```

## Минимальные системные требования

- Docker 20.10+
- 8GB RAM (16GB рекомендуется)
- 15GB свободного места
- NVIDIA GPU + nvidia-docker (опционально)
- Linux Ubuntu 20.04+

## Команды для отладки

```bash
# Подключение к контейнеру
./run_docker.sh shell

# Проверка переменных окружения
./run_docker.sh shell -c 'env | grep KEY'

# Проверка модели Whisper
./run_docker.sh shell -c 'python3 -c "from faster_whisper import WhisperModel; print(\"OK\")"'

# Проверка GPU внутри контейнера
./run_docker.sh shell -c 'nvidia-smi'
```

## Проверочный чеклист

- [ ] Docker установлен и запущен
- [ ] NVIDIA драйверы установлены (для GPU)
- [ ] Файл .env создан с ключами
- [ ] Порт 8000 свободен
- [ ] Образ stenogramma собран
- [ ] Контейнер запущен и отвечает
- [ ] Клиентские зависимости установлены
- [ ] Тестовый аудиофайл готов

## Быстрая диагностика

```bash
#!/bin/bash
echo "=== STENOGRAMMA DIAGNOSTIC ==="
echo "Docker: $(docker --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'NOT AVAILABLE')"
echo "Image: $(docker images stenogramma:latest --format 'table {{.Repository}}:{{.Tag}}' 2>/dev/null || echo 'NOT BUILT')"
echo "Container: $(docker ps --filter name=stenogramma --format 'table {{.Names}} {{.Status}}' 2>/dev/null || echo 'NOT RUNNING')"
echo "Port 8000: $(curl -s http://localhost:8000/endpoint_info && echo 'OK' || echo 'NOT ACCESSIBLE')"
```