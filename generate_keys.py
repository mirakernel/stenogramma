#!/usr/bin/env python3
"""
Утилита для генерации криптографических ключей для сервиса транскрибации
"""

import secrets
import os

def generate_aes_key():
    """Генерирует 32-байтный ключ для AES-256"""
    return secrets.token_bytes(32)

def generate_secret_endpoint():
    """Генерирует секретный эндпоинт"""
    return secrets.token_urlsafe(32)

def main():
    print("=== Генератор ключей для сервиса транскрибации ===\n")
    
    # Генерация ключей
    decrypt_key = generate_aes_key()
    encrypt_key = generate_aes_key()
    secret_endpoint = generate_secret_endpoint()
    
    # Конвертация в hex формат
    decrypt_key_hex = decrypt_key.hex()
    encrypt_key_hex = encrypt_key.hex()
    
    print("Сгенерированные ключи:")
    print("=" * 50)
    print(f"SECRET_ENDPOINT={secret_endpoint}")
    print(f"KEY_DECRYPT={decrypt_key_hex}")
    print(f"KEY_ENCRYPT={encrypt_key_hex}")
    print("=" * 50)
    
    # Сохранение в .env файл
    env_content = f"""# Конфигурация сервиса транскрибации
# ВНИМАНИЕ: Эти ключи сгенерированы автоматически. Храните их в безопасности!

SECRET_ENDPOINT={secret_endpoint}
KEY_DECRYPT={decrypt_key_hex}
KEY_ENCRYPT={encrypt_key_hex}
"""
    
    with open('.env', 'w') as f:
        f.write(env_content)
    
    print("\n✅ Ключи сохранены в файл .env")
    print("\n⚠️  ВАЖНО:")
    print("   - Не передавайте эти ключи по незащищённым каналам")
    print("   - Не commit'те файл .env в git")
    print("   - Сделайте резервную копию ключей в безопасном месте")
    print("   - Для продакшена используйте переменные окружения")

if __name__ == "__main__":
    main()