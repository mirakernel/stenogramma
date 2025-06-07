#!/usr/bin/env python3
"""
Автономный тест криптографических функций
"""

import os
import secrets
from crypto_utils import encrypt_data, decrypt_data

def test_basic_encryption():
    """Базовый тест шифрования/расшифрования"""
    print("🔐 Тестирование базового шифрования...")
    
    # Тестовые данные
    test_data = "Hello, World! Это тест шифрования на русском языке.".encode('utf-8')
    test_key = secrets.token_bytes(32)  # 256-bit ключ
    
    try:
        # Шифрование
        encrypted = encrypt_data(test_data, test_key)
        print(f"   Исходные данные: {len(test_data)} байт")
        print(f"   Зашифрованные данные: {len(encrypted)} байт")
        
        # Расшифрование
        decrypted = decrypt_data(encrypted, test_key)
        print(f"   Расшифрованные данные: {len(decrypted)} байт")
        
        # Проверка
        if decrypted == test_data:
            print("✅ Тест пройден: данные совпадают")
            return True
        else:
            print("❌ Тест провален: данные не совпадают")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка теста: {e}")
        return False

def test_different_keys():
    """Тест с разными ключами"""
    print("\n🔑 Тестирование с разными ключами...")
    
    test_data = "Secret message".encode('utf-8')
    key1 = secrets.token_bytes(32)
    key2 = secrets.token_bytes(32)
    
    try:
        # Шифруем одним ключом
        encrypted = encrypt_data(test_data, key1)
        
        # Пытаемся расшифровать другим ключом
        try:
            decrypt_data(encrypted, key2)
            print("❌ Тест провален: расшифровка успешна с неправильным ключом")
            return False
        except:
            print("✅ Тест пройден: расшифровка невозможна с неправильным ключом")
            return True
            
    except Exception as e:
        print(f"❌ Ошибка теста: {e}")
        return False

def test_large_data():
    """Тест с большими данными"""
    print("\n📊 Тестирование больших данных...")
    
    # Создаем данные размером ~1MB
    test_data = ("A" * (1024 * 1024)).encode('utf-8')
    test_key = secrets.token_bytes(32)
    
    try:
        encrypted = encrypt_data(test_data, test_key)
        decrypted = decrypt_data(encrypted, test_key)
        
        if decrypted == test_data:
            print(f"✅ Тест пройден: обработано {len(test_data)} байт")
            return True
        else:
            print("❌ Тест провален: данные не совпадают")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка теста: {e}")
        return False

def test_empty_data():
    """Тест с пустыми данными"""
    print("\n📭 Тестирование пустых данных...")
    
    test_data = "".encode('utf-8')
    test_key = secrets.token_bytes(32)
    
    try:
        encrypted = encrypt_data(test_data, test_key)
        decrypted = decrypt_data(encrypted, test_key)
        
        if decrypted == test_data:
            print("✅ Тест пройден: пустые данные обработаны корректно")
            return True
        else:
            print("❌ Тест провален: данные не совпадают")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка теста: {e}")
        return False

def test_unicode_data():
    """Тест с Unicode данными"""
    print("\n🌍 Тестирование Unicode данных...")
    
    test_text = "Привет, мир! 🌍 Hello, World! 你好世界！"
    test_data = test_text.encode('utf-8')
    test_key = secrets.token_bytes(32)
    
    try:
        encrypted = encrypt_data(test_data, test_key)
        decrypted = decrypt_data(encrypted, test_key)
        decrypted_text = decrypted.decode('utf-8')
        
        if decrypted_text == test_text:
            print("✅ Тест пройден: Unicode данные обработаны корректно")
            return True
        else:
            print("❌ Тест провален: данные не совпадают")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка теста: {e}")
        return False

def main():
    print("🧪 Автономный тест криптографических функций")
    print("=" * 50)
    
    tests = [
        test_basic_encryption,
        test_different_keys,
        test_large_data,
        test_empty_data,
        test_unicode_data
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
    
    print("\n" + "=" * 50)
    print(f"📊 Результат: {passed}/{total} тестов пройдено")
    
    if passed == total:
        print("🎉 Все тесты пройдены! Криптографические функции работают корректно.")
        return True
    else:
        print("❌ Некоторые тесты провалены. Проверьте реализацию crypto_utils.")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)