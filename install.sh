#!/bin/bash

echo "========================================"
echo "   Установка Screen Recorder"
echo "========================================"
echo ""

echo "Установка зависимостей..."
sudo apt update
sudo apt install -y ffmpeg x11-utils

echo ""
echo "Создание скриптов..."

cat > screen_recorder.sh << 'EOF'
#!/bin/bash

RECORDINGS_DIR="$HOME/screen_recordings"
mkdir -p "$RECORDINGS_DIR"

DURATION_MINUTES=1
FPS=15
CRF=28
RETENTION_HOURS=48

log() {
    echo "[$(date '+%Y%m%d-%H%M%S')] $1"
}

get_hour_folder() {
    local timestamp=$(date +"%y%m%d-%H")
    echo "$RECORDINGS_DIR/$timestamp"
}

check_dependencies() {
    if ! command -v ffmpeg &> /dev/null; then
        log "ОШИБКА: Установите ffmpeg: sudo apt install ffmpeg"
        exit 1
    fi
    
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
    fi
}

get_screen_resolution() {
    if command -v xdpyinfo &> /dev/null; then
        xdpyinfo | grep dimensions | awk '{print $2}' 2>/dev/null || echo "1920x1080"
    else
        echo "1920x1080"
    fi
}

cleanup_old_recordings() {
    if [ "$RETENTION_HOURS" -gt 0 ]; then
        find "$RECORDINGS_DIR" -type d -name "*" -mmin +$((RETENTION_HOURS * 60)) -exec rm -rf {} + 2>/dev/null
    fi
}

record_screen() {
    local resolution=$(get_screen_resolution)
    log "Запуск записи с разрешением: $resolution"
    
    local last_cleanup=$(date +%s)
    
    while true; do
        local hour_folder=$(get_hour_folder)
        mkdir -p "$hour_folder"
        
        local timestamp=$(date +"%M%S")
        local filename="record_${timestamp}.mp4"
        local filepath="$hour_folder/$filename"
        
        ffmpeg -f x11grab \
               -video_size "$resolution" \
               -framerate $FPS \
               -i "${DISPLAY:-:0}" \
               -t $((DURATION_MINUTES * 60)) \
               -c:v libx264 \
               -preset fast \
               -crf $CRF \
               -pix_fmt yuv420p \
               -y "$filepath" > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            log "✓ $(basename "$hour_folder")/$filename"
        else
            log "✗ Ошибка записи"
            sleep 5
        fi
        
        local current_time=$(date +%s)
        if [ $((current_time - last_cleanup)) -gt 1800 ]; then
            cleanup_old_recordings
            last_cleanup=$current_time
        fi
        
        sleep 1
    done
}

main() {
    log "🚀 Screen Recorder запущен"
    log "Настройки: ${DURATION_MINUTES} мин/файл, ${FPS} FPS"
    
    check_dependencies
    cleanup_old_recordings
    record_screen
}

trap 'log "Завершение работы..."; exit 0' SIGINT SIGTERM
main
EOF

cat > manager.sh << 'EOF'
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/screen_recorder.sh"
PID_FILE="$HOME/.screen_recorder.pid"
LOG_FILE="$HOME/.screen_recorder.log"
RECORDINGS_DIR="$HOME/screen_recordings"

show_header() {
    clear
    echo -e "${BLUE}"
    echo "========================================="
    echo "      УПРАВЛЕНИЕ ЗАПИСЬЮ ЭКРАНА"
    echo "========================================="
    echo -e "${NC}"
}

start_recording() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo -e "${YELLOW}Запись уже запущена (PID: $(cat $PID_FILE))${NC}"
        return
    fi
    
    echo -e "${GREEN}▶  Запуск записи экрана...${NC}"
    nohup bash "$MAIN_SCRIPT" >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo -e "${GREEN}✓ Запись запущена!${NC}"
    echo "Логи: $LOG_FILE"
    echo "Папка записей: $RECORDINGS_DIR"
}

stop_recording() {
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${YELLOW}Запись не запущена${NC}"
        return
    fi
    
    local PID=$(cat "$PID_FILE")
    echo -e "${YELLOW}⏹  Остановка записи (PID: $PID)...${NC}"
    
    kill $PID 2>/dev/null
    sleep 2
    
    if kill -0 $PID 2>/dev/null; then
        kill -9 $PID
    fi
    
    rm -f "$PID_FILE"
    echo -e "${GREEN}✓ Запись остановлена${NC}"
}

show_status() {
    echo -e "${BLUE}Статус:${NC}"
    
    if [ -f "$PID_FILE" ]; then
        local PID=$(cat "$PID_FILE")
        if kill -0 $PID 2>/dev/null; then
            echo -e "${GREEN}✓ Запись активна (PID: $PID)${NC}"
            echo "Время работы: $(ps -p $PID -o etime= 2>/dev/null || echo '?')"
        else
            echo -e "${RED}✗ Процесс не найден${NC}"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "${YELLOW}✗ Запись не запущена${NC}"
    fi
}

show_recordings() {
    echo -e "${BLUE}Записи:${NC}"
    
    if [ -d "$RECORDINGS_DIR" ]; then
        local total_size=$(du -sh "$RECORDINGS_DIR" 2>/dev/null | cut -f1)
        local total_folders=$(find "$RECORDINGS_DIR" -type d -name "*" | wc -l)
        local total_files=$(find "$RECORDINGS_DIR" -name "*.mp4" | wc -l)
        
        echo "Папка: $RECORDINGS_DIR"
        echo "Размер: ${total_size:-0}"
        echo "Часов записей: $total_folders"
        echo "Файлов: $total_files"
        echo ""
        echo "Последние 5 часов записей:"
        find "$RECORDINGS_DIR" -maxdepth 1 -type d -name "*" | sort -r | head -5 | while read folder; do
            if [ "$folder" != "$RECORDINGS_DIR" ]; then
                local hour=$(basename "$folder")
                local files=$(find "$folder" -name "*.mp4" | wc -l)
                local size=$(du -sh "$folder" 2>/dev/null | cut -f1)
                echo "  📁 $hour : $files файлов ($size)"
            fi
        done
    else
        echo "Папка записей пуста"
    fi
}

open_folder() {
    if [ -d "$RECORDINGS_DIR" ]; then
        echo -e "${GREEN}📁 Открываю папку с записями...${NC}"
        xdg-open "$RECORDINGS_DIR" 2>/dev/null || echo "Папка: $RECORDINGS_DIR"
    else
        echo "Папка записей не найдена"
    fi
}

show_logs() {
    echo -e "${BLUE}Логи:${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        tail -20 "$LOG_FILE"
    else
        echo "Логи не найдены"
    fi
}

setup_autostart() {
    echo -e "${BLUE}Автозапуск:${NC}"
    
    read -p "Добавить в автозагрузку? (y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        local autostart_file="$HOME/.config/autostart/screen-recorder.desktop"
        mkdir -p "$(dirname "$autostart_file")"
        cat > "$autostart_file" << DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=Screen Recorder
Exec=$SCRIPT_DIR/manager.sh start
Hidden=false
X-GNOME-Autostart-enabled=true
DESKTOP_EOF
        echo -e "${GREEN}✓ Автозагрузка добавлена${NC}"
    fi
}

show_menu() {
    while true; do
        show_header
        
        echo -e "${BLUE}МЕНЮ:${NC}"
        echo -e "  ${GREEN}1) ▶  Начать запись${NC}"
        echo -e "  ${RED}2) ⏹  Остановить запись${NC}"
        echo -e "  ${YELLOW}3) 🔄 Перезапустить${NC}"
        echo -e "  ${BLUE}4) 📊 Статус${NC}"
        echo -e "  ${BLUE}5) 📁 Показать записи${NC}"
        echo -e "  ${BLUE}6) 📂 Открыть папку${NC}"
        echo -e "  ${BLUE}7) 📝 Показать логи${NC}"
        echo -e "  ${BLUE}8) ⚙️  Автозапуск${NC}"
        echo -e "  ${RED}9) ❌ Выход${NC}"
        echo ""
        
        read -p "Выберите действие [1-9]: " choice
        
        case $choice in
            1) start_recording ;;
            2) stop_recording ;;
            3) stop_recording; sleep 2; start_recording ;;
            4) show_status; read -p "Нажмите Enter...";;
            5) show_recordings; read -p "Нажмите Enter...";;
            6) open_folder; read -p "Нажмите Enter...";;
            7) show_logs; read -p "Нажмите Enter...";;
            8) setup_autostart; read -p "Нажмите Enter...";;
            9) echo "До свидания!"; exit 0 ;;
            *) echo "Неверный выбор";;
        esac
    done
}

case "${1:-menu}" in
    start)
        start_recording
        ;;
    stop)
        stop_recording
        ;;
    restart)
        stop_recording
        sleep 2
        start_recording
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    menu)
        show_menu
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status|logs|menu}"
        exit 1
        ;;
esac
EOF

chmod +x screen_recorder.sh manager.sh

echo ""
echo "✅ Установка завершена!"
echo ""
echo "Используйте команды:"
echo "  ./manager.sh start    - начать запись"
echo "  ./manager.sh stop     - остановить запись"
echo "  ./manager.sh menu     - открыть меню управления"
echo ""
echo "Записи сохраняются в: ~/screen_recordings/"
echo "Структура: ГГММДД-ЧЧ/МИНУТЫ.mp4"
