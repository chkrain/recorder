#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PID_FILE="/tmp/screen_recorder.pid"
LOG_FILE="/tmp/screen_recorder.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/screen_recorder.sh"

show_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║             УПРАВЛЕНИЕ SCREEN RECORDER                  ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

start_recorder() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo -e "${YELLOW}Запись уже запущена (PID: $(cat $PID_FILE))${NC}"
        return
    fi
    
    echo -e "${GREEN}Запуск записи экрана...${NC}"
    nohup "$MAIN_SCRIPT" >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo -e "${GREEN}✓ Запись запущена!${NC}"
    echo "Записи сохраняются в: ~/screen_recordings/"
    echo "Для остановки: $0 stop"
}

stop_recorder() {
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${YELLOW}Запись не запущена${NC}"
        return
    fi
    
    PID=$(cat "$PID_FILE")
    if kill -0 $PID 2>/dev/null; then
        echo -e "${YELLOW}Остановка записи...${NC}"
        kill $PID
        sleep 2
        if kill -0 $PID 2>/dev/null; then
            kill -9 $PID
        fi
        echo -e "${GREEN}✓ Запись остановлена${NC}"
    fi
    rm -f "$PID_FILE"
}

show_status() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 $PID 2>/dev/null; then
            echo -e "${GREEN}✓ Запись активна (PID: $PID)${NC}"
            echo "Время работы: $(ps -p $PID -o etime= 2>/dev/null || echo 'неизвестно')"
        else
            echo -e "${RED}✗ Процесс не найден${NC}"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "${YELLOW}✗ Запись не запущена${NC}"
    fi
    
    echo -e "\n${BLUE}Папка записей:${NC}"
    ls -la ~/screen_recordings/ 2>/dev/null | head -10 || echo "Папка пуста"
    
    echo -e "\n${BLUE}Последние логи:${NC}"
    tail -5 "$LOG_FILE" 2>/dev/null || echo "Логи не найдены"
}

show_settings() {
    CONFIG_FILE="$HOME/.screen_recorder_config"
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${BLUE}Текущие настройки:${NC}"
        cat "$CONFIG_FILE" | while read line; do
            echo "  $line"
        done
    else
        echo -e "${YELLOW}Настройки не найдены${NC}"
    fi
}

show_stats() {
    RECORDINGS_DIR="$HOME/screen_recordings"
    if [ -d "$RECORDINGS_DIR" ]; then
        count=$(find "$RECORDINGS_DIR" -name "*.mp4" -type f | wc -l)
        size=$(du -sh "$RECORDINGS_DIR" 2>/dev/null | cut -f1 || echo "0")
        echo -e "${BLUE}Статистика:${NC}"
        echo "  Файлов: $count"
        echo "  Размер: $size"
        echo "  Последние файлы:"
        ls -lt "$RECORDINGS_DIR"/*.mp4 2>/dev/null | head -5 | awk '{print "    " $9}' || echo "    Нет файлов"
    else
        echo "Папка записей не найдена"
    fi
}

open_folder() {
    RECORDINGS_DIR="$HOME/screen_recordings"
    if [ -d "$RECORDINGS_DIR" ]; then
        echo -e "${GREEN}Открываю папку с записями...${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open "$RECORDINGS_DIR"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            xdg-open "$RECORDINGS_DIR" 2>/dev/null || nautilus "$RECORDINGS_DIR" 2>/dev/null || echo "Откройте вручную: $RECORDINGS_DIR"
        else
            echo "Папка: $RECORDINGS_DIR"
        fi
    else
        echo "Папка записей не найдена"
    fi
}

show_header

case "${1:-menu}" in
    start)
        start_recorder
        ;;
    stop)
        stop_recorder
        ;;
    restart)
        stop_recorder
        sleep 2
        start_recorder
        ;;
    status)
        show_status
        ;;
    settings)
        show_settings
        ;;
    stats)
        show_stats
        ;;
    folder)
        open_folder
        ;;
    menu)
        while true; do
            echo -e "\n${BLUE}МЕНЮ:${NC}"
            echo "  1) ▶  Начать запись"
            echo "  2) ⏹  Остановить запись"
            echo "  3) 🔄 Перезапустить"
            echo "  4) 📊 Статус"
            echo "  5) ⚙️  Настройки"
            echo "  6) 📈 Статистика"
            echo "  7) 📁 Открыть папку"
            echo "  8) ❌ Выход"
            echo ""
            read -p "Выберите действие [1-8]: " choice
            
            case $choice in
                1) start_recorder ;;
                2) stop_recorder ;;
                3) stop_recorder; sleep 2; start_recorder ;;
                4) show_status ;;
                5) show_settings ;;
                6) show_stats ;;
                7) open_folder ;;
                8) echo "До свидания!"; exit 0 ;;
                *) echo "Неверный выбор" ;;
            esac
        done
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status|settings|stats|folder|menu}"
        ;;
esac
