import os
import secrets
import torch
from fastapi import FastAPI, UploadFile, HTTPException, Response
from faster_whisper import WhisperModel
from crypto_utils import encrypt_data, decrypt_data

app = FastAPI()

# Генерация секретного эндпоинта
ENDPOINT = os.getenv("SECRET_ENDPOINT", secrets.token_urlsafe(32))

# Загрузка ключей из переменных окружения
KEY_DECRYPT_STR = os.getenv("KEY_DECRYPT")
KEY_ENCRYPT_STR = os.getenv("KEY_ENCRYPT")

# Проверка инициализации ключей
if not KEY_DECRYPT_STR or not KEY_ENCRYPT_STR:
    raise RuntimeError("Encryption keys not configured!")

KEY_DECRYPT = KEY_DECRYPT_STR.encode('utf-8')  # Для входящих файлов
KEY_ENCRYPT = KEY_ENCRYPT_STR.encode('utf-8')  # Для исходящих текстов

# Инициализация модели Whisper с автоопределением устройства
model_size = "large-v3"
device = "cuda" if torch.cuda.is_available() else "cpu"
compute_type = "float16" if torch.cuda.is_available() else "int8"

print(f"🎯 Инициализация Whisper модели: {model_size}")
print(f"🖥️  Устройство: {device}")
print(f"⚙️  Тип вычислений: {compute_type}")

model = WhisperModel(
    model_size,
    device=device,
    compute_type=compute_type
)

@app.post(f"/{ENDPOINT}")
async def process_lecture(file: UploadFile):
    # 1. Проверка типа файла
    if not file.filename or not file.filename.endswith('.wav'):
        raise HTTPException(400, "Only .wav files accepted")

    # Создание директории для временных файлов
    temp_dir = "temp"
    os.makedirs(temp_dir, exist_ok=True)
    
    # Генерация имени временного файла
    temp_filename = os.path.join(temp_dir, f"temp_audio_{secrets.token_urlsafe(8)}.wav")

    try:
        # 2. Расшифровка аудио
        encrypted_audio = await file.read()
        decrypted_audio = decrypt_data(encrypted_audio, KEY_DECRYPT)

        # 3. Сохранение во временный файл
        with open(temp_filename, "wb") as f:
            f.write(decrypted_audio)

        # 4. Транскрибация
        segments, _ = model.transcribe(
            temp_filename,
            language="ru",
            beam_size=5,
            vad_filter=True
        )

        transcript = "\n".join(segment.text for segment in segments)

        # 5. Шифрование результата
        encrypted_result = encrypt_data(transcript.encode('utf-8'), KEY_ENCRYPT)

        # 6. Очистка
        if os.path.exists(temp_filename):
            os.remove(temp_filename)

        return Response(
            content=encrypted_result,
            media_type="application/octet-stream",
            headers={"Content-Disposition": "attachment;filename=encrypted_result.bin"}
        )

    except Exception as e:
        # Очистка в случае ошибки
        if os.path.exists(temp_filename):
            os.remove(temp_filename)
        raise HTTPException(500, f"Processing error: {str(e)}")

@app.get("/endpoint_info")
async def get_endpoint():
    return {"endpoint": ENDPOINT}
