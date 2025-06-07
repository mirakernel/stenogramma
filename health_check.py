#!/usr/bin/env python3
"""
Скрипт для проверки работоспособности системы транскрибации
"""

import os
import sys
import requests
import secrets
from crypto_utils import encrypt_data, decrypt_data

class HealthChecker:
    def __init__(self):
        self.errors = []
        self.warnings = []
        
    def check_environment(self):
        """Проверка переменных окружения"""
        print("🔧 Проверка переменных окружения...")
        
        required_vars = ['SECRET_ENDPOINT', 'KEY_DECRYPT', 'KEY_ENCRYPT']
        missing_vars = []
        
        for var in required_vars:
            if not os.getenv(var):
                missing_vars.append(var)
        
        if missing_vars:
            self.errors.append(f"Отсутствуют переменные окружения: {', '.join(missing_vars)}")
            return False
        
        # Проверка длины ключей
        try:
            key_decrypt = os.getenv('KEY_DECRYPT')
            key_encrypt = os.getenv('KEY_ENCRYPT')
            
            if len(key_decrypt) != 64:
                self.errors.append("KEY_DECRYPT должен быть 64 символа (32 байта в hex)")
            if len(key_encrypt) != 64:
                self.errors.append("KEY_ENCRYPT должен быть 64 символа (32 байта в hex)")
            
            # Попытка конвертации в байты
            bytes.fromhex(key_decrypt)
            bytes.fromhex(key_encrypt)
            
        except ValueError:
            self.errors.append("Ключи должны быть в hex формате")
            return False
            
        print("✅ Переменные окружения настроены корректно")
        return True
    
    def check_crypto(self):
        """Проверка криптографических функций"""
        print("🔐 Проверка шифрования...")
        
        try:
            # Тестовые данные
            test_data = "Hello, World! Тест шифрования.".encode('utf-8')
            test_key = secrets.token_bytes(32)
            
            # Шифрование
            encrypted = encrypt_data(test_data, test_key)
            
            # Расшифрование
            decrypted = decrypt_data(encrypted, test_key)
            
            if decrypted != test_data:
                self.errors.append("Ошибка в функциях шифрования/расшифрования")
                return False
                
            print("✅ Криптографические функции работают корректно")
            return True
            
        except Exception as e:
            self.errors.append(f"Ошибка криптографии: {e}")
            return False
    
    def check_dependencies(self):
        """Проверка зависимостей"""
        print("📦 Проверка зависимостей...")
        
        try:
            import fastapi
            import faster_whisper
            from Crypto.Cipher import AES
            print("✅ Все зависимости установлены")
            return True
        except ImportError as e:
            self.errors.append(f"Отсутствует зависимость: {e}")
            return False
    
    def check_gpu(self):
        """Проверка доступности GPU"""
        print("🎮 Проверка GPU...")
        
        try:
            import torch
            if torch.cuda.is_available():
                gpu_count = torch.cuda.device_count()
                gpu_name = torch.cuda.get_device_name(0)
                print(f"✅ GPU доступен: {gpu_name} (устройств: {gpu_count})")
                return True
            else:
                self.warnings.append("GPU недоступен, будет использоваться CPU (медленнее)")
                return False
        except ImportError:
            self.warnings.append("PyTorch не установлен, не могу проверить GPU")
            return False
    
    def check_server(self, server_url="http://localhost:8000"):
        """Проверка доступности сервера"""
        print(f"🌐 Проверка сервера {server_url}...")
        
        try:
            response = requests.get(f"{server_url}/endpoint_info", timeout=5)
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Сервер доступен, эндпоинт: {data.get('endpoint', 'N/A')}")
                return True
            else:
                self.errors.append(f"Сервер недоступен: HTTP {response.status_code}")
                return False
        except requests.exceptions.ConnectionError:
            self.warnings.append("Сервер не запущен или недоступен")
            return False
        except Exception as e:
            self.errors.append(f"Ошибка подключения к серверу: {e}")
            return False
    
    def check_temp_directory(self):
        """Проверка временной директории"""
        print("📁 Проверка временной директории...")
        
        try:
            temp_dir = "temp"
            os.makedirs(temp_dir, exist_ok=True)
            
            # Проверка записи
            test_file = os.path.join(temp_dir, "test_write.tmp")
            with open(test_file, "w") as f:
                f.write("test")
            
            # Проверка чтения
            with open(test_file, "r") as f:
                content = f.read()
            
            # Очистка
            os.remove(test_file)
            
            if content == "test":
                print("✅ Временная директория работает корректно")
                return True
            else:
                self.errors.append("Ошибка записи/чтения во временную директорию")
                return False
                
        except Exception as e:
            self.errors.append(f"Ошибка работы с временной директорией: {e}")
            return False
    
    def run_full_check(self):
        """Запуск полной проверки"""
        print("🏥 Проверка работоспособности системы")
        print("=" * 50)
        
        checks = [
            self.check_dependencies,
            self.check_environment,
            self.check_crypto,
            self.check_temp_directory,
            self.check_gpu,
            self.check_server
        ]
        
        passed = 0
        total = len(checks)
        
        for check in checks:
            if check():
                passed += 1
            print()
        
        print("=" * 50)
        print(f"📊 Результат: {passed}/{total} проверок пройдено")
        
        if self.warnings:
            print("\n⚠️  Предупреждения:")
            for warning in self.warnings:
                print(f"   • {warning}")
        
        if self.errors:
            print("\n❌ Ошибки:")
            for error in self.errors:
                print(f"   • {error}")
            print("\n🔧 Рекомендации по исправлению:")
            print("   1. Убедитесь, что все зависимости установлены: pip install -r requirements.txt")
            print("   2. Настройте переменные окружения: python3 generate_keys.py")
            print("   3. Запустите сервер: uvicorn app:app --host 0.0.0.0 --port 8000")
            return False
        else:
            print("\n🎉 Все проверки пройдены! Система готова к работе.")
            return True

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--server-url":
        server_url = sys.argv[2] if len(sys.argv) > 2 else "http://localhost:8000"
    else:
        server_url = os.getenv("SERVER_URL", "http://localhost:8000")
    
    checker = HealthChecker()
    success = checker.run_full_check()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()