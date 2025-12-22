#!/bin/bash
# Скрипт для настройки времени хранения записей

CONFIG_FILE="$HOME/.screen_recorder_config"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    MAX_HOURS=48  
fi

echo "Текущее время хранения: $MAX_HOURS часов"
echo ""
echo "Выберите время хранения записей:"
echo "1) 10 часов"
echo "2) 20 часов"
echo "3) 24 часа (1 день)"
echo "4) 48 часов (2 дня)"
echo "5) 72 часа (3 дня)"
echo "6) 168 часов (7 дней)"
echo "7) Другое значение"
echo ""

read -p "Выберите вариант [1-7]: " choice

case $choice in
    1) MAX_HOURS=10 ;;
    2) MAX_HOURS=20 ;;
    3) MAX_HOURS=24 ;;
    4) MAX_HOURS=48 ;;
    5) MAX_HOURS=72 ;;
    6) MAX_HOURS=168 ;;
    7)
        read -p "Введите количество часов: " custom_hours
        if [[ $custom_hours =~ ^[0-9]+$ ]] && [ $custom_hours -gt 0 ]; then
            MAX_HOURS=$custom_hours
        else
            echo "Ошибка: введите положительное число"
            exit 1
        fi
        ;;
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

# Сохраняем настройки
echo "MAX_HOURS=$MAX_HOURS" > "$CONFIG_FILE"
echo "Установлено время хранения: $MAX_HOURS часов"

# Обновляем основной скрипт
SCREEN_RECORDER="$HOME/screen_recorder.sh"
if [ -f "$SCREEN_RECORDER" ]; then
    sed -i "s/MAX_HOURS=[0-9]*/MAX_HOURS=$MAX_HOURS/" "$SCREEN_RECORDER"
    echo "Основной скрипт обновлен"
fi
