#!/usr/bin/env python3
"""
Клиентская утилита для безопасной отправки аудиофайлов на сервис транскрибации
"""

import os
import sys
import argparse
import requests
from crypto_utils import encrypt_data, decrypt_data

def load_env_vars():
    """Загружает переменные окружения"""
    try:
        # Попытка загрузить из .env файла
        if os.path.exists('.env'):
            with open('.env', 'r') as f:
                for line in f:
                    if line.strip() and not line.startswith('#'):
                        key, value = line.strip().split('=', 1)
                        os.environ[key] = value
        
        server_url = os.getenv('SERVER_URL', 'http://localhost:8000')
        secret_endpoint = os.getenv('SECRET_ENDPOINT')
        key_encrypt = os.getenv('KEY_DECRYPT')  # Для клиента это ключ шифрования
        key_decrypt = os.getenv('KEY_ENCRYPT')  # Для клиента это ключ расшифровки
        
        if not all([secret_endpoint, key_encrypt, key_decrypt]):
            raise ValueError("Не все переменные окружения настроены")
        
        # Дополнительная проверка для типизации
        assert secret_endpoint is not None
        assert key_encrypt is not None
        assert key_decrypt is not None
            
        return server_url, secret_endpoint, bytes.fromhex(key_encrypt), bytes.fromhex(key_decrypt)
        
    except Exception as e:
        print(f"❌ Ошибка загрузки конфигурации: {e}")
        print("Убедитесь, что файл .env существует и содержит все необходимые переменные:")
        print("- SECRET_ENDPOINT")
        print("- KEY_DECRYPT")
        print("- KEY_ENCRYPT")
        print("- SERVER_URL (опционально, по умолчанию http://localhost:8000)")
        sys.exit(1)

def encrypt_audio_file(file_path, key):
    """Шифрует аудиофайл"""
    try:
        with open(file_path, 'rb') as f:
            audio_data = f.read()
        
        print(f"📁 Загружен файл: {file_path} ({len(audio_data)} байт)")
        encrypted_data = encrypt_data(audio_data, key)
        print(f"🔐 Файл зашифрован ({len(encrypted_data)} байт)")
        
        return encrypted_data
    except Exception as e:
        print(f"❌ Ошибка шифрования файла: {e}")
        sys.exit(1)

def send_to_server(encrypted_data, server_url, endpoint, original_filename):
    """Отправляет зашифрованные данные на сервер"""
    try:
        url = f"{server_url}/{endpoint}"
        print(f"🌐 Отправка на сервер: {url}")
        
        files = {
            'file': (f"encrypted_{original_filename}", encrypted_data, 'audio/wav')
        }
        
        response = requests.post(url, files=files, timeout=1300)  # 15 минут таймаут
        
        if response.status_code == 200:
            print("✅ Файл успешно обработан сервером")
            return response.content
        else:
            print(f"❌ Ошибка сервера: {response.status_code}")
            print(f"Детали: {response.text}")
            sys.exit(1)
            
    except requests.exceptions.Timeout:
        print("❌ Таймаут запроса. Возможно, файл слишком большой или сервер перегружен")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Ошибка отправки: {e}")
        sys.exit(1)

def decrypt_result(encrypted_result, key):
    """Расшифровывает результат от сервера"""
    try:
        decrypted_data = decrypt_data(encrypted_result, key)
        transcript = decrypted_data.decode('utf-8')
        print("🔓 Результат расшифрован")
        return transcript
    except Exception as e:
        print(f"❌ Ошибка расшифровки результата: {e}")
        sys.exit(1)

def save_transcript(transcript, output_file):
    """Сохраняет транскрипт в файл"""
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(transcript)
        print(f"💾 Транскрипт сохранён в: {output_file}")
    except Exception as e:
        print(f"❌ Ошибка сохранения файла: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Клиент для безопасной транскрибации аудио')
    parser.add_argument('audio_file', help='Путь к аудиофайлу (.wav)')
    parser.add_argument('-o', '--output', help='Файл для сохранения транскрипта (по умолчанию: transcript.txt)')
    
    args = parser.parse_args()
    
    # Проверка входного файла
    if not os.path.exists(args.audio_file):
        print(f"❌ Файл не найден: {args.audio_file}")
        sys.exit(1)
    
    if not args.audio_file.lower().endswith('.wav'):
        print("❌ Поддерживаются только файлы .wav")
        sys.exit(1)
    
    # Определение выходного файла
    output_file = args.output or 'transcript.txt'
    
    print("🎵 Клиент безопасной транскрибации аудио")
    print("=" * 50)
    
    # Загрузка конфигурации
    server_url, secret_endpoint, encrypt_key, decrypt_key = load_env_vars()
    
    # Шифрование файла
    encrypted_audio = encrypt_audio_file(args.audio_file, encrypt_key)
    
    # Отправка на сервер
    encrypted_result = send_to_server(
        encrypted_audio, 
        server_url, 
        secret_endpoint, 
        os.path.basename(args.audio_file)
    )
    
    # Расшифровка результата
    transcript = decrypt_result(encrypted_result, decrypt_key)
    
    # Сохранение
    save_transcript(transcript, output_file)
    
    print("=" * 50)
    print("🎉 Транскрибация завершена успешно!")
    print(f"📄 Результат: {len(transcript)} символов")

if __name__ == "__main__":
    main()