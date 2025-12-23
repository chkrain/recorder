#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.screen_recorder_config"

echo ""
echo "========================================"
echo "   Настройка Screen Recorder"
echo "========================================"
echo ""

echo "=== Настройка времени записи ==="
read -p "Длительность одного видеофайла (в минутах) [по умолчанию 5]: " segment_minutes
if [[ -z "$segment_minutes" ]]; then
    segment_minutes=5
fi
SEGMENT_DURATION=$((segment_minutes * 60))

echo ""

echo "=== Настройка времени хранения ==="
read -p "Хранить записи (в минутах) [по умолчанию 2880 (48 часов)]: " retention_minutes
if [[ -z "$retention_minutes" ]]; then
    retention_minutes=2880
fi
RETENTION_TIME=$retention_minutes

echo ""

echo "=== Настройка качества записи ==="
echo "Выберите качество записи:"
echo "1) Низкое (быстрая обработка, большой размер)"
echo "2) Среднее (рекомендуется)"
echo "3) Высокое (качественное видео)"
echo "4) Очень высокое (максимальное качество)"
read -p "Выберите вариант [1-4]: " quality_choice

case $quality_choice in
    1) QUALITY="low"; FPS=5 ;;
    2) QUALITY="medium"; FPS=10 ;;
    3) QUALITY="high"; FPS=15 ;;
    4) QUALITY="veryhigh"; FPS=30 ;;
    *) QUALITY="medium"; FPS=10 ;;
esac

echo ""

echo "=== Настройка ограничения памяти ==="
read -p "Включить ограничение по памяти? (y/n) [n]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ENABLE_STORAGE_LIMIT=1
    read -p "Максимальный объем для хранения (в ГБ) [5]: " max_gb
    if [[ -z "$max_gb" ]]; then
        max_gb=5
    fi
    MAX_STORAGE_GB=$max_gb
else
    ENABLE_STORAGE_LIMIT=0
    MAX_STORAGE_GB=5
fi

cat > "$CONFIG_FILE" << EOF
SEGMENT_DURATION=$SEGMENT_DURATION
RETENTION_TIME=$RETENTION_TIME
MAX_STORAGE_GB=$MAX_STORAGE_GB
ENABLE_STORAGE_LIMIT=$ENABLE_STORAGE_LIMIT
FPS=$FPS
QUALITY="$QUALITY"
EOF

echo ""
echo "========================================"
echo "   Настройка завершена!"
echo "========================================"
echo "	 Параметры:"
echo " - Длительность видео: $segment_minutes мин."
echo " - Время хранения: $retention_minutes мин."
echo " - Качество: $QUALITY (FPS: $FPS)"
echo " - Ограничение памяти: $( [ "$ENABLE_STORAGE_LIMIT" -eq 1 ] && echo "Да (${MAX_STORAGE_GB}GB)" || echo "Нет" )"
echo "========================================"
echo ""
echo "	 Для запуска: ./daemon.sh start"
