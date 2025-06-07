import os
import secrets
import torch
import logging
from fastapi import FastAPI, UploadFile, HTTPException, Response
from faster_whisper import WhisperModel
from crypto_utils import encrypt_data, decrypt_data

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI()

# Генерация секретного эндпоинта
ENDPOINT = os.getenv("SECRET_ENDPOINT", secrets.token_urlsafe(32))

# Загрузка ключей из переменных окружения
KEY_DECRYPT_STR = os.getenv("KEY_DECRYPT")
KEY_ENCRYPT_STR = os.getenv("KEY_ENCRYPT")

# Проверка инициализации ключей
if not KEY_DECRYPT_STR or not KEY_ENCRYPT_STR:
    raise RuntimeError("Encryption keys not configured!")

KEY_DECRYPT = bytes.fromhex(KEY_DECRYPT_STR)  # Для входящих файлов
KEY_ENCRYPT = bytes.fromhex(KEY_ENCRYPT_STR)  # Для исходящих текстов

# Инициализация модели Whisper с автоопределением устройства
model_size = "large-v3"
device = "cuda" if torch.cuda.is_available() else "cpu"
compute_type = "float16" if torch.cuda.is_available() else "int8"

print(f"🎯 Инициализация Whisper модели: {model_size}")
print(f"🖥️  Устройство: {device}")
print(f"⚙️  Тип вычислений: {compute_type}")

logger.info(f"Инициализация Whisper модели: {model_size}, устройство: {device}, тип: {compute_type}")

model = WhisperModel(
    model_size,
    device=device,
    compute_type=compute_type
)

logger.info("Модель Whisper успешно загружена")

@app.post(f"/{ENDPOINT}")
async def process_lecture(file: UploadFile):
    logger.info(f"Получен запрос на обработку файла: {file.filename}")
    
    # 1. Проверка типа файла
    if not file.filename or not file.filename.endswith('.wav'):
        logger.warning(f"Отклонен файл неподдерживаемого типа: {file.filename}")
        raise HTTPException(400, "Only .wav files accepted")

    # Создание директории для временных файлов
    temp_dir = "temp"
    os.makedirs(temp_dir, exist_ok=True)
    
    # Генерация имени временного файла
    temp_filename = os.path.join(temp_dir, f"temp_audio_{secrets.token_urlsafe(8)}.wav")
    logger.debug(f"Создан временный файл: {temp_filename}")

    try:
        # 2. Расшифровка аудио
        logger.info("Чтение зашифрованных данных...")
        encrypted_audio = await file.read()
        logger.info(f"Получено {len(encrypted_audio)} байт зашифрованных данных")
        
        logger.info("Расшифровка аудио...")
        decrypted_audio = decrypt_data(encrypted_audio, KEY_DECRYPT)
        logger.info(f"Расшифровано {len(decrypted_audio)} байт аудиоданных")

        # 3. Сохранение во временный файл
        logger.info(f"Сохранение во временный файл: {temp_filename}")
        with open(temp_filename, "wb") as f:
            f.write(decrypted_audio)
        logger.info("Временный файл создан успешно")

        # 4. Транскрибация
        logger.info("Начало транскрибации...")
        segments, _ = model.transcribe(
            temp_filename,
            language="ru",
            beam_size=5,
            vad_filter=True
        )

        logger.info("Обработка сегментов транскрибации...")
        transcript = "\n".join(segment.text for segment in segments)
        logger.info(f"Транскрибация завершена. Получено {len(transcript)} символов текста")

        # 5. Шифрование результата
        logger.info("Шифрование результата...")
        encrypted_result = encrypt_data(transcript.encode('utf-8'), KEY_ENCRYPT)
        logger.info(f"Результат зашифрован: {len(encrypted_result)} байт")

        # 6. Очистка
        if os.path.exists(temp_filename):
            os.remove(temp_filename)
            logger.debug(f"Временный файл удален: {temp_filename}")

        logger.info("Обработка файла завершена успешно")
        return Response(
            content=encrypted_result,
            media_type="application/octet-stream",
            headers={"Content-Disposition": "attachment;filename=encrypted_result.bin"}
        )

    except Exception as e:
        logger.error(f"Ошибка при обработке файла: {str(e)}", exc_info=True)
        # Очистка в случае ошибки
        if os.path.exists(temp_filename):
            os.remove(temp_filename)
            logger.debug(f"Временный файл удален после ошибки: {temp_filename}")
        raise HTTPException(500, f"Processing error: {str(e)}")

@app.get("/endpoint_info")
async def get_endpoint():
    return {"endpoint": ENDPOINT}
