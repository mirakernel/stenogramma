# 🧪 TEST - Тестирование Stenogramma

## Быстрая проверка системы

```bash
# Проверка всех компонентов одной командой
./test_system.sh
```

## Пошаговое тестирование

### 1. Проверка Docker и GPU
```bash
# Проверка Docker
docker --version
docker info

# Проверка GPU
nvidia-smi

# Тест NVIDIA Docker
docker run --rm --gpus all nvidia/cuda:12.9.0-base-ubuntu22.04 nvidia-smi
```

### 2. Генерация ключей
```bash
python3 generate_keys.py
cat .env
```

### 3. Сборка образа
```bash
# Автоматическая сборка (определит GPU/CPU сама)
./build_docker.sh

# При ошибках PyTorch/CUDA - быстрое исправление
./quick_fix.sh

# Принудительно GPU (если есть)
./build_docker.sh --gpu

# Принудительно CPU (всегда работает)
./build_docker.sh --cpu
```

### 4. Запуск сервиса
```bash
# Автоматический запуск
./run_docker.sh start

# Проверка статуса
./run_docker.sh status

# Просмотр логов
./run_docker.sh logs
```

### 5. Тестирование API
```bash
# Проверка эндпоинта
curl http://localhost:8000/endpoint_info

# Должен вернуть что-то вроде:
# {"endpoint":"ваш_секретный_эндпоинт"}
```

### 6. Тестирование клиента
```bash
# Установка клиентских зависимостей
pip install -r requirements-client.txt

# Создание тестового аудиофайла (если нет)
# ffmpeg -f lavfi -i "sine=frequency=1000:duration=5" -ar 16000 test_audio.wav

# Тестирование транскрибации
python3 client.py test_audio.wav -o result.txt
cat result.txt
```

## Команды для отладки

### Проблемы с образами
```bash
# При ошибках PyTorch/CUDA - быстрое исправление
./quick_fix.sh

# При ошибках CUDA образов
./fix_docker.sh

# Очистка всех образов
docker system prune -a -f

# Повторная сборка
./build_docker.sh --no-cache
```

### Проблемы с контейнером
```bash
# Подключение к контейнеру
./run_docker.sh shell

# Перезапуск
./run_docker.sh restart

# Полная очистка и перезапуск
./run_docker.sh remove
./run_docker.sh start
```

### Диагностика
```bash
# Проверка переменных окружения
./run_docker.sh shell -c 'env | grep -E "(SECRET|KEY)"'

# Проверка GPU внутри контейнера
./run_docker.sh shell -c 'nvidia-smi'

# Проверка модели Whisper
./run_docker.sh shell -c 'python3 -c "from faster_whisper import WhisperModel; print(\"OK\")"'
```

## Ожидаемые результаты

### Успешная сборка
```
✅ Docker готов к работе (версия: XX.XX.X)
✅ NVIDIA Docker поддержка работает
✅ Все необходимые файлы найдены
✅ Выбран GPU образ (автоматически)
✅ Образ успешно собран: stenogramma:latest
```

### Успешный запуск
```
✅ Выбран GPU образ (автоматически)
✅ Контейнер 'stenogramma' запущен в background режиме
🟢 Запущен
🎮 Режим: GPU
🌐 Сервис доступен на http://localhost:8000
```

### Успешная транскрибация
```
📁 Загружен файл: test_audio.wav (XXXX байт)
🔐 Файл зашифрован (XXXX байт)
🌐 Отправка на сервер: http://localhost:8000/ваш_эндпоинт
✅ Файл успешно обработан сервером
🔓 Результат расшифрован
💾 Транскрипт сохранён в: result.txt
🎉 Транскрибация завершена успешно!
```

## Частые проблемы и решения

| Проблема | Команда решения |
|----------|-----------------|
| PyTorch/CUDA ошибки | `./quick_fix.sh` |
| CUDA образ не найден | `./fix_docker.sh` |
| Порт занят | `./run_docker.sh -p 9000 start` |
| GPU недоступен | `./run_docker.sh --cpu start` |
| Ключи не настроены | `python3 generate_keys.py` |
| Контейнер не запускается | `./run_docker.sh logs` |
| API недоступен | `./run_docker.sh restart` |

## Один тест - все проверки
```bash
# Полный цикл тестирования одной командой
./test_system.sh && \
echo "=== BUILDING ===" && \
(./build_docker.sh || ./quick_fix.sh) && \
echo "=== STARTING ===" && \
./run_docker.sh start && \
echo "=== TESTING API ===" && \
sleep 10 && \
curl http://localhost:8000/endpoint_info && \
echo -e "\n=== SUCCESS ==="
```