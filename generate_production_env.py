#!/usr/bin/env python3
"""
Генератор production-готового .env файла для Stenogramma
Создает криптографически стойкие ключи для продакшн среды
"""

import secrets
import os
import sys
from datetime import datetime

def generate_aes_key():
    """Генерирует 32-байтный ключ для AES-256"""
    return secrets.token_bytes(32)

def generate_secret_endpoint():
    """Генерирует криптографически стойкий секретный эндпоинт"""
    return secrets.token_urlsafe(48)  # Более длинный для продакшена

def validate_environment():
    """Проверяет готовность к продакшену"""
    warnings = []
    
    # Проверка что мы не в debug режиме
    if os.getenv('DEBUG', '').lower() in ('true', '1', 'on'):
        warnings.append("DEBUG режим включен")
    
    # Проверка наличия HTTPS
    if not os.getenv('HTTPS_ENABLED', '').lower() in ('true', '1', 'on'):
        warnings.append("HTTPS не настроен")
    
    return warnings

def create_production_env():
    """Создает production .env файл"""
    
    # Генерация ключей
    key_decrypt = generate_aes_key().hex()
    key_encrypt = generate_aes_key().hex()
    secret_endpoint = generate_secret_endpoint()
    
    # Создание содержимого файла
    timestamp = datetime.now().isoformat()
    
    env_content = f"""# Stenogramma Production Environment Configuration
# Generated: {timestamp}
# CRITICAL: Keep these keys secure and never share them!

# Secret endpoint for audio processing (48 characters)
SECRET_ENDPOINT={secret_endpoint}

# AES-256 encryption keys (64 hex characters each)
KEY_DECRYPT={key_decrypt}
KEY_ENCRYPT={key_encrypt}

# Production settings
ENVIRONMENT=production
DEBUG=false
LOG_LEVEL=INFO

# Security headers
SECURE_HEADERS=true
CORS_ALLOWED_ORIGINS=https://yourdomain.com

# Rate limiting (requests per minute per IP)
RATE_LIMIT=10

# Maximum file size in MB
MAX_FILE_SIZE=200

# Model settings for production
WHISPER_MODEL=large-v3
WHISPER_DEVICE=cuda
WHISPER_COMPUTE_TYPE=float16

# Monitoring
HEALTH_CHECK_ENABLED=true
METRICS_ENABLED=true

# Logging
LOG_FORMAT=json
LOG_FILE=/var/log/stenogramma/app.log

# Backup encryption key (for key rotation)
BACKUP_KEY_DECRYPT={generate_aes_key().hex()}
BACKUP_KEY_ENCRYPT={generate_aes_key().hex()}
"""

    return env_content, key_decrypt, key_encrypt, secret_endpoint

def save_keys_backup(keys_data):
    """Сохраняет резервную копию ключей"""
    backup_content = f"""# Stenogramma Keys Backup
# Generated: {datetime.now().isoformat()}
# Store this file in a secure location!

MAIN_DECRYPT_KEY={keys_data['decrypt']}
MAIN_ENCRYPT_KEY={keys_data['encrypt']}
SECRET_ENDPOINT={keys_data['endpoint']}
BACKUP_DECRYPT_KEY={keys_data['backup_decrypt']}
BACKUP_ENCRYPT_KEY={keys_data['backup_encrypt']}

# Recovery instructions:
# 1. Copy the needed keys to your .env file
# 2. Restart the service
# 3. Update your client configuration
"""
    
    backup_filename = f"keys_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    
    with open(backup_filename, 'w') as f:
        f.write(backup_content)
    
    return backup_filename

def main():
    print("🔐 Production Environment Generator для Stenogramma")
    print("=" * 60)
    
    # Проверка текущего окружения
    warnings = validate_environment()
    if warnings:
        print("⚠️  Предупреждения окружения:")
        for warning in warnings:
            print(f"   • {warning}")
        print()
    
    # Проверка существующего .env файла
    if os.path.exists('.env'):
        print("⚠️  Файл .env уже существует!")
        response = input("Перезаписать? Это удалит текущие ключи! (yes/NO): ").strip().lower()
        if response not in ['yes', 'y']:
            print("❌ Операция отменена")
            sys.exit(0)
        
        # Создание резервной копии
        backup_name = f".env.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        os.rename('.env', backup_name)
        print(f"📋 Старый .env сохранен как: {backup_name}")
    
    # Генерация нового .env файла
    print("🔑 Генерация криптографических ключей...")
    env_content, key_decrypt, key_encrypt, secret_endpoint = create_production_env()
    
    # Сохранение .env файла
    with open('.env', 'w') as f:
        f.write(env_content)
    
    # Установка безопасных прав доступа
    os.chmod('.env', 0o600)
    
    # Создание резервной копии ключей
    keys_data = {
        'decrypt': key_decrypt,
        'encrypt': key_encrypt,
        'endpoint': secret_endpoint,
        'backup_decrypt': env_content.split('BACKUP_KEY_DECRYPT=')[1].split('\n')[0],
        'backup_encrypt': env_content.split('BACKUP_KEY_ENCRYPT=')[1].split('\n')[0]
    }
    
    backup_file = save_keys_backup(keys_data)
    
    print("✅ Production .env файл создан успешно!")
    print()
    print("📊 Сгенерированные компоненты:")
    print(f"   • Секретный эндпоинт: {len(secret_endpoint)} символов")
    print(f"   • Ключ расшифровки: 256-bit AES")
    print(f"   • Ключ шифрования: 256-bit AES")
    print(f"   • Резервные ключи: 2x 256-bit AES")
    print()
    print(f"💾 Резервная копия ключей: {backup_file}")
    print(f"🔒 Права доступа .env: 600 (только владелец)")
    print()
    print("🚀 Инструкции по развертыванию:")
    print("=" * 40)
    print("1. Сборка Docker образа:")
    print("   ./build_docker.sh")
    print()
    print("2. Запуск production контейнера:")
    print("   ./run_docker.sh start")
    print()
    print("3. Проверка статуса:")
    print("   ./run_docker.sh status")
    print()
    print("4. Просмотр логов:")
    print("   ./run_docker.sh logs")
    print()
    print("🔐 КРИТИЧЕСКИЕ МЕРЫ БЕЗОПАСНОСТИ:")
    print("=" * 40)
    print("❗ НИКОГДА не передавайте .env файл по незащищенным каналам")
    print("❗ Храните резервную копию ключей в безопасном месте")
    print("❗ Используйте HTTPS в продакшене")
    print("❗ Настройте файрвол для ограничения доступа")
    print("❗ Регулярно ротируйте ключи")
    print("❗ Мониторьте логи на предмет подозрительной активности")
    print()
    print("📋 Для клиентов:")
    print("   Эндпоинт API: https://yourdomain.com/" + secret_endpoint)
    print("   Ключ шифрования (для клиента): " + key_decrypt)
    print("   Ключ расшифровки (для клиента): " + key_encrypt)
    print()
    print("✅ Готово для продакшн развертывания!")

if __name__ == "__main__":
    main()