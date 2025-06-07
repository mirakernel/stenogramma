# 🎵 Stenogramma - Безопасный сервис транскрибации аудио

Высокозащищённый сервис для преобразования 40-минутных аудиолекций в текст с использованием end-to-end шифрования и GPU ускорения.

**🧪 Для тестирования**: см. [TEST.md](TEST.md) или запустите `./test_system.sh`

## 🛡️ Особенности безопасности

- **End-to-End шифрование**: AES-256 шифрование на стороне клиента
- **Секретные эндпоинты**: Случайно генерируемые URL для максимальной безопасности
- **Изолированная среда**: Работа в Docker контейнере с минимальными привилегиями
- **Автоматическая очистка**: Временные файлы удаляются после обработки
- **GPU ускорение**: Быстрая обработка с поддержкой NVIDIA GPU

## 🚀 Быстрое развертывание

### 1. Клонирование проекта

```bash
git clone <repository-url>
cd stenogramma
```

### 2. Генерация ключей безопасности

```bash
# Для тестирования
python3 generate_keys.py

# Для продакшена (рекомендуется)
python3 generate_production_env.py
```

### 3. Проверка системы (опционально)

```bash
# Быстрая проверка готовности системы
./test_system.sh
```

### 4. Сборка Docker образа

```bash
# Автоматическая сборка (рекомендуется для CUDA 12.9.0+)
./build_docker.sh

# При ошибках CUDA образов - автоисправление
./fix_docker.sh && ./build_docker.sh

# Принудительно CPU версия (гарантированно работает)
./build_docker.sh --cpu
```

### 5. Запуск сервиса

```bash
# Запуск с GPU (рекомендуется)
./run_docker.sh start

# Запуск без GPU
./run_docker.sh start --no-gpu

# Запуск на другом порту
./run_docker.sh -p 9000 start
```

### 6. Проверка работы

```bash
# Проверка статуса
./run_docker.sh status

# Просмотр логов
./run_docker.sh logs

# Проверка доступности API
curl http://localhost:8000/endpoint_info
```

## 📱 Использование клиентом

### Установка клиентских зависимостей

```bash
pip install -r requirements-client.txt
```

### Транскрибация аудиофайла

```bash
# Базовое использование
python3 client.py your_lecture.wav

# Указание выходного файла
python3 client.py lecture.wav -o transcript.txt

# Помощь
python3 client.py --help
```

### Пример полного цикла

```bash
# 1. У вас есть аудиофайл lecture.wav (40 минут, 75MB)
# 2. Клиент автоматически зашифрует файл
# 3. Отправит на сервер по секретному эндпоинту
# 4. Получит зашифрованный текст
# 5. Расшифрует и сохранит в transcript.txt
python3 client.py lecture.wav
```

## 🛠️ Управление контейнером

### Основные команды

```bash
# Запуск
./run_docker.sh start

# Остановка
./run_docker.sh stop

# Перезапуск
./run_docker.sh restart

# Статус
./run_docker.sh status

# Логи (в реальном времени)
./run_docker.sh logs

# Подключение к контейнеру
./run_docker.sh shell

# Удаление контейнера
./run_docker.sh remove
```

### Дополнительные опции

```bash
# Запуск с кастомным именем
./run_docker.sh -n my-stenogramma start

# Использование другого .env файла
./run_docker.sh -e .env.production start

# Принудительно GPU или CPU образ
./run_docker.sh --gpu start
./run_docker.sh --cpu start

# Интерактивный запуск (для отладки)
./run_docker.sh --interactive start
```
</edits>

## 📋 Требования

### Системные требования

- **Docker**: 20.10+ с поддержкой GPU runtime
- **NVIDIA GPU**: С поддержкой CUDA 11.8+
- **RAM**: Минимум 8GB, рекомендуется 16GB
- **Дисковое пространство**: 15GB для образа и модели
- **ОС**: Linux (Ubuntu 20.04+), поддержка NVIDIA Container Toolkit

### Проверка совместимости

```bash
# Проверка Docker
docker --version

# Проверка GPU поддержки
nvidia-smi
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu22.04 nvidia-smi

# Проверка всей системы
python3 health_check.py
```

## 🔧 Конфигурация

### Переменные окружения (.env файл)

```env
# Обязательные переменные
SECRET_ENDPOINT=ваш_секретный_эндпоинт_48_символов
KEY_DECRYPT=64_символа_hex_ключ_для_расшифровки
KEY_ENCRYPT=64_символа_hex_ключ_для_шифрования

# Опциональные настройки
WHISPER_MODEL=large-v3
MAX_FILE_SIZE=200
RATE_LIMIT=10
```

### Поддерживаемые форматы

- **Формат**: `.wav` файлы
- **Рекомендуемые параметры**: 16kHz, 16-bit, моно
- **Максимальный размер**: 200MB (~2 часа аудио)
- **Оптимальная длительность**: 30-60 минут

## 🔒 Безопасность в продакшене

### Обязательные меры

1. **Используйте production ключи**:
   ```bash
   python3 generate_production_env.py
   ```

2. **Настройте HTTPS** через reverse proxy (nginx/traefik)

3. **Ограничьте доступ** через файрвол:
   ```bash
   # Разрешить только с определенных IP
   iptables -A INPUT -p tcp --dport 8000 -s YOUR_CLIENT_IP -j ACCEPT
   iptables -A INPUT -p tcp --dport 8000 -j DROP
   ```

4. **Мониторинг логов**:
   ```bash
   # Непрерывный мониторинг
   ./run_docker.sh logs | grep -E "(ERROR|WARNING|CRITICAL)"
   ```

### Резервное копирование

```bash
# Бэкап ключей
cp .env .env.backup.$(date +%Y%m%d)

# Бэкап логов
docker logs stenogramma > logs_backup_$(date +%Y%m%d).txt
```

## 🚨 Решение проблем

### Проблемы запуска

**Ошибка**: `Encryption keys not configured!`
```bash
# Решение: Проверьте .env файл
cat .env
python3 generate_keys.py
```

**Ошибка**: `CUDA not available`
```bash
# Решение: Запуск без GPU
./run_docker.sh --cpu start
```

**Ошибка**: `nvidia/cuda:11.8-devel-ubuntu22.04: not found`
```bash
# Решение: Автоисправление Docker образов
./fix_docker.sh
./build_docker.sh

# Или принудительно CPU версия
./build_docker.sh --cpu
./run_docker.sh --cpu start
```

**Ошибка**: `Port already in use`
```bash
# Решение: Используйте другой порт
./run_docker.sh -p 9000 start
```

### Проблемы обработки

**Ошибка**: `Only .wav files accepted`
```bash
# Конвертация в wav
ffmpeg -i input.mp3 -ar 16000 -ac 1 output.wav
```

**Ошибка**: `File too large`
```bash
# Сжатие аудио
ffmpeg -i input.wav -ar 16000 -ab 64k output.wav
```

### Проблемы производительности

**Медленная обработка**:
- Убедитесь что используется GPU: `./run_docker.sh logs | grep -i gpu`
- Проверьте загрузку GPU: `nvidia-smi`

**Нехватка памяти**:
- Уменьшите размер файла
- Перезапустите контейнер: `./run_docker.sh restart`

## 📊 Производительность

### Ожидаемые показатели

- **40-минутная лекция** (75MB): ~3-5 минут обработки на GPU
- **Точность транскрибации**: ~95% для качественного русского аудио
- **Скорость**: 10-15x быстрее реального времени на GPU
- **Потребление памяти**: 6-8GB GPU RAM

### Оптимизация

```bash
# Для более быстрой обработки (менее точно)
# Измените в app.py: model_size = "medium"

# Для максимальной точности (медленнее)
# Используйте: model_size = "large-v3" (по умолчанию)
```

## 📋 API документация

### Эндпоинты

- `POST /{SECRET_ENDPOINT}` - Обработка зашифрованного аудиофайла
- `GET /endpoint_info` - Получение информации о секретном эндпоинте

### Пример запроса

```bash
# Получение эндпоинта
curl http://localhost:8000/endpoint_info

# Отправка файла (используйте клиент для автоматического шифрования)
python3 client.py your_audio.wav
```

### Формат ответа

Сервер возвращает зашифрованный текст, который автоматически расшифруется клиентом.

## 🔧 Кастомизация

### Изменение модели Whisper

В файле `app.py`:
```python
# Варианты: tiny, base, small, medium, large-v3
model_size = "large-v3"  # Лучшая точность
# model_size = "medium"  # Баланс скорости и качества
```

### Настройка языка

```python
segments, _ = model.transcribe(
    temp_filename,
    language="ru",    # Русский по умолчанию
    beam_size=5,      # Качество декодирования
    vad_filter=True   # Фильтр пауз
)
```

## 📞 Мониторинг и поддержка

### Проверка здоровья системы

```bash
# Полная проверка
python3 health_check.py

# Тест криптографии
python3 test_crypto.py

# Проверка Docker контейнера
./run_docker.sh status
```

### Логирование

```bash
# Все логи
./run_docker.sh logs

# Только ошибки
./run_docker.sh logs | grep ERROR

# Сохранить логи в файл
./run_docker.sh logs > debug.log
```

## ⚡ Быстрый чеклист для деплоя

1. ✅ `git clone` и `cd stenogramma`
2. ✅ `./test_system.sh` (проверка системы)
3. ✅ `python3 generate_production_env.py`
4. ✅ `./build_docker.sh` (автосборка для CUDA 12.9.0+)
5. ✅ `./run_docker.sh start`
6. ✅ `./run_docker.sh status`
7. ✅ Тест: `python3 client.py test_audio.wav`

**При проблемах**: см. [TEST.md](TEST.md) для подробной диагностики

## 📄 Лицензия и безопасность

Этот сервис предназначен для безопасной обработки конфиденциальных аудиоданных. 

**⚠️ ВАЖНО**: 
- Никогда не передавайте ключи шифрования третьим лицам
- Используйте HTTPS в продакшене
- Регулярно обновляйте ключи безопасности
- Мониторьте доступ к сервису

---

**Версия**: 1.0.0  
**Поддерживаемые GPU**: NVIDIA с CUDA 12.9.0+ (совместимость с 11.8+)  
**Тестировано на**: Linux Ubuntu 22.04, Docker 24.0+, CUDA 12.9.0

**Файлы для тестирования**:
- [TEST.md](TEST.md) - подробное тестирование
- [QUICKSTART.md](QUICKSTART.md) - быстрый старт
- `./test_system.sh` - автоматическая проверка системы