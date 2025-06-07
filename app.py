import os
import secrets
from fastapi import FastAPI, UploadFile, HTTPException, Response
from faster_whisper import WhisperModel
from crypto_utils import encrypt_data, decrypt_data

app = FastAPI()

# Генерация секретного эндпоинта
ENDPOINT = os.getenv("SECRET_ENDPOINT", secrets.token_urlsafe(32))

# Загрузка ключей из переменных окружения
KEY_DECRYPT = os.getenv("KEY_DECRYPT").encode('utf-8')  # Для входящих файлов
KEY_ENCRYPT = os.getenv("KEY_ENCRYPT").encode('utf-8')  # Для исходящих текстов

# Проверка инициализации ключей
if not KEY_DECRYPT or not KEY_ENCRYPT:
    raise RuntimeError("Encryption keys not configured!")

# Инициализация модели Whisper
model_size = "large-v3"
model = WhisperModel(
    model_size,
    device="cuda",
    compute_type="float16"
)

@app.post(f"/{ENDPOINT}")
async def process_lecture(file: UploadFile):
    # 1. Проверка типа файла
    if not file.filename.endswith('.wav'):
        raise HTTPException(400, "Only .wav files accepted")

    try:
        # 2. Расшифровка аудио
        encrypted_audio = await file.read()
        decrypted_audio = decrypt_data(encrypted_audio, KEY_DECRYPT)

        # 3. Сохранение во временный файл
        with open("temp_audio.wav", "wb") as f:
            f.write(decrypted_audio)

        # 4. Транскрибация
        segments, _ = model.transcribe(
            "temp_audio.wav",
            language="ru",
            beam_size=5,
            vad_filter=True
        )

        transcript = "\n".join(segment.text for segment in segments)

        # 5. Шифрование результата
        encrypted_result = encrypt_data(transcript.encode('utf-8'), KEY_ENCRYPT)

        # 6. Очистка
        os.remove("temp_audio.wav")

        return Response(
            content=encrypted_result,
            media_type="application/octet-stream",
            headers={"Content-Disposition": "attachment;filename=encrypted_result.bin"}
        )

    except Exception as e:
        raise HTTPException(500, f"Processing error: {str(e)}")

@app.get("/endpoint_info")
async def get_endpoint():
    return {"endpoint": ENDPOINT}
