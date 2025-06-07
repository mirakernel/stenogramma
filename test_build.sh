#!/bin/bash
echo "🧪 Тестирование сборки..."

# Проверка ключей
if [ ! -f ".env" ]; then
    echo "📝 Генерация ключей..."
    python3 generate_keys.py
fi

# Сборка образа
echo "🔨 Сборка Docker образа..."
docker build -t stenogramma:test .

if [ $? -eq 0 ]; then
    echo "✅ Сборка успешна!"
    echo "🚀 Попробуйте запустить: ./run_docker.sh start"
else
    echo "❌ Ошибка сборки"
    exit 1
fi
