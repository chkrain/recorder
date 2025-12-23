#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         АВТОМАТИЧЕСКИЙ SCREEN RECORDER                   ║"
echo "║               Установка за 1 минуту                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
echo -e "${BLUE}Обнаружена ОС: $OS${NC}"

install_dependencies() {
    echo -e "\n${YELLOW}Установка необходимых зависимостей...${NC}"
    
    case $OS in
        linux)
            if command -v apt-get &> /dev/null; then
                echo "Установка через apt..."
                sudo apt-get update
                sudo apt-get install -y ffmpeg x11-utils bc curl
            elif command -v yum &> /dev/null; then
                echo "Установка через yum..."
                sudo yum install -y ffmpeg xorg-x11-server-utils bc curl
            elif command -v pacman &> /dev/null; then
                echo "Установка через pacman..."
                sudo pacman -Sy --noconfirm ffmpeg xorg-xdpyinfo bc curl
            else
                echo -e "${RED}Не удалось определить пакетный менеджер${NC}"
                echo "Установите вручную: ffmpeg, x11-utils, bc"
            fi
            ;;
        macos)
            echo "Установка через Homebrew..."
            if ! command -v brew &> /dev/null; then
                echo "Установка Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install ffmpeg
            ;;
        windows)
            echo -e "${YELLOW}Для Windows требуется установка вручную:${NC}"
            echo "1. Скачайте FFmpeg: https://ffmpeg.org/download.html"
            echo "2. Добавьте в PATH"
            echo "3. Перезапустите терминал"
            read -p "Нажмите Enter после установки FFmpeg..."
            ;;
    esac
}

setup_configuration() {
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                     НАСТРОЙКА РЕКОРДЕРА                   ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${YELLOW}1. Длительность одного видеофайла:${NC}"
    echo "   (сколько минут будет длиться каждый отдельный файл)"
    echo "   Пример: 5 = файлы по 5 минут, 10 = файлы по 10 минут"
    
    while true; do
        read -p "   Введите длительность (минут) [5]: " duration
        if [[ -z "$duration" ]]; then
            duration=5
            break
        elif [[ "$duration" =~ ^[0-9]+$ ]] && [ "$duration" -ge 1 ] && [ "$duration" -le 60 ]; then
            break
        else
            echo -e "   ${RED}Ошибка: введите число от 1 до 60${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}2. Время хранения записей:${NC}"
    echo "   (через сколько минут старые записи будут удаляться)"
    echo "   1 = 1 минута, 1440 = 1 день, 10080 = 1 неделя"
    
    while true; do
        read -p "   Введите время хранения (минут) [10]: " retention_min
        if [[ -z "$retention_min" ]]; then
            retention_min=7
            break
        elif [[ "$retention_min" =~ ^[0-9]+$ ]] && [ "$retention_min" -ge 1 ]; then
            break
        else
            echo -e "   ${RED}Ошибка: введите положительное число${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}3. Качество записи:${NC}"
    echo "   1) 📱 Низкое (мало места, быстро)"
    echo "   2) 💻 Среднее (рекомендуется)"
    echo "   3) 🖥️  Высокое (лучшее качество)"
    
    while true; do
        read -p "   Выберите качество [2]: " quality_choice
        case $quality_choice in
            1|"")
                quality="low"
                fps=10
                crf=32
                break
                ;;
            2)
                quality="medium"
                fps=15
                crf=28
                break
                ;;
            3)
                quality="high"
                fps=30
                crf=23
                break
                ;;
            *)
                echo -e "   ${RED}Ошибка: выберите 1, 2 или 3${NC}"
                ;;
        esac
    done
    
    echo -e "\n${YELLOW}4. Ограничение по памяти:${NC}"
    echo "   (максимальный размер папки с записями)"
    echo "   Если включено - удаляет самые старые видео при превышении лимита"
    
    read -p "   Включить ограничение по памяти? (y/N): " enable_limit
    if [[ "$enable_limit" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "   Максимальный размер (ГБ) [10]: " max_gb
            if [[ -z "$max_gb" ]]; then
                max_gb=10
                break
            elif [[ "$max_gb" =~ ^[0-9]+$ ]] && [ "$max_gb" -ge 1 ]; then
                break
            else
                echo -e "   ${RED}Ошибка: введите положительное число${NC}"
            fi
        done
        storage_limit=1
    else
        max_gb=0
        storage_limit=0
    fi
    
    CONFIG_FILE="$HOME/.screen_recorder_config"
    cat > "$CONFIG_FILE" << EOF
DURATION_MINUTES=$duration
RETENTION_MIN=$retention_min
QUALITY="$quality"
FPS=$fps
CRF=$crf
MAX_STORAGE_GB=$max_gb
ENABLE_STORAGE_LIMIT=$storage_limit
EOF
    
    echo -e "\n${GREEN}✓ Настройки сохранены!${NC}"
}

create_scripts() {
    echo -e "\n${YELLOW}Создание рабочих скриптов...${NC}"
    
    cat > screen_recorder.sh << 'EOF'
#!/bin/bash

CONFIG_FILE="$HOME/.screen_recorder_config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    DURATION_MINUTES=5
    RETENTION_MIN=60
    QUALITY="medium"
    FPS=15
    CRF=28
    MAX_STORAGE_GB=0
    ENABLE_STORAGE_LIMIT=0
fi

SEGMENT_DURATION=$((DURATION_MINUTES * 60))
RETENTION_MINUTES=$((RETENTION_MIN))

RECORDINGS_DIR="$HOME/screen_recordings"
mkdir -p "$RECORDINGS_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_folder_size_gb() {
    if command -v du &> /dev/null; then
        du -sb "$RECORDINGS_DIR" 2>/dev/null | awk '{printf "%.2f", $1/1024/1024/1024}'
    else
        echo "0"
    fi
}

cleanup_old_files() {
    log "Проверка старых файлов..."
    
    if command -v find &> /dev/null; then
        find "$RECORDINGS_DIR" -name "*.mp4" -type f -mmin +$RETENTION_MINUTES -delete 2>/dev/null
        log "Удалены файлы старше $RETENTION_MIN имнут"
    fi
    
    if [ "$ENABLE_STORAGE_LIMIT" -eq 1 ] && [ "$MAX_STORAGE_GB" -gt 0 ]; then
        local current_size=$(get_folder_size_gb)
        if (( $(echo "$current_size > $MAX_STORAGE_GB" | bc -l 2>/dev/null || echo "0") )); then
            log "Превышен лимит: ${current_size}GB > ${MAX_STORAGE_GB}GB"
            log "Удаляю самые старые файлы..."
            
            find "$RECORDINGS_DIR" -name "*.mp4" -type f -printf '%T+ %p\n' 2>/dev/null | \
                sort | head -n 10 | cut -d' ' -f2- | while read file; do
                rm -f "$file"
                log "Удалён: $(basename "$file")"
                
                current_size=$(get_folder_size_gb)
                if (( $(echo "$current_size <= $MAX_STORAGE_GB" | bc -l 2>/dev/null || echo "1") )); then
                    break
                fi
            done
        fi
    fi
}

get_screen_resolution() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v xdpyinfo &> /dev/null; then
            xdpyinfo | grep dimensions | awk '{print $2}' 2>/dev/null
        elif command -v xrandr &> /dev/null; then
            xrandr | grep '*' | head -1 | awk '{print $1}' 2>/dev/null
        else
            echo "1920x1080"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        system_profiler SPDisplaysDataType | grep Resolution | head -1 | awk '{print $2"x"$4}'
    else
        echo "1920x1080"
    fi
}

record_screen() {
    local session_id=$(date +"%Y%m%d_%H%M%S")
    local segment_num=0
    local last_cleanup=$(date +%s)
    
    local resolution=$(get_screen_resolution)
    log "Разрешение экрана: $resolution"
    
    local display="${DISPLAY:-:0}"
    log "Используется дисплей: $display"
    
    while true; do
        local timestamp=$(date +"%d%m-%H%M")
        local filename="record_${timestamp}_${segment_num}.mp4"
        local filepath="$RECORDINGS_DIR/$filename"
        
        log "Начало записи: $filename (${DURATION_MINUTES} мин, $QUALITY)"
        
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            ffmpeg -f x11grab \
                   -video_size "$resolution" \
                   -framerate $FPS \
                   -i "$display" \
                   -t $SEGMENT_DURATION \
                   -c:v libx264 \
                   -preset fast \
                   -crf $CRF \
                   -pix_fmt yuv420p \
                   "$filepath" > /dev/null 2>&1
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            ffmpeg -f avfoundation \
                   -capture_cursor 1 \
                   -i "1:0" \
                   -t $SEGMENT_DURATION \
                   -c:v libx264 \
                   -preset fast \
                   -crf $CRF \
                   -pix_fmt yuv420p \
                   "$filepath" > /dev/null 2>&1
        fi
        
        if [ $? -eq 0 ]; then
            log "Запись завершена: $filename"
        else
            log "Ошибка записи, пауза 5 секунд..."
            sleep 5
            continue
        fi
        
        segment_num=$((segment_num + 1))
        
        local current_time=$(date +%s)
        if [ $((current_time - last_cleanup)) -gt 1800 ]; then
            cleanup_old_files
            last_cleanup=$current_time
        fi
        
        sleep 1
    done
}

check_dependencies() {
    if ! command -v ffmpeg &> /dev/null; then
        log "Ошибка: ffmpeg не установлен!"
        log "Запустите setup.sh для установки"
        exit 1
    fi
    
    if [[ "$OSTYPE" == "linux-gnu"* ]] && [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
        log "Установлен DISPLAY=:0"
    fi
}

main() {
    log "Запуск Screen Recorder"
    log "Папка записей: $RECORDINGS_DIR"
    log "Настройки: ${DURATION_MINUTES}мин/файл, хранение: ${RETENTION_MIN}m, качество: $QUALITY"
    
    check_dependencies
    cleanup_old_files
    record_screen
}

main
EOF

    cat > recorder_manager.sh << 'EOF'
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
EOF

    chmod +x screen_recorder.sh recorder_manager.sh
    
    echo -e "${GREEN}✓ Скрипты созданы!${NC}"
}

setup_autostart() {
    echo -e "\n${YELLOW}Настройка автозапуска...${NC}"
    
    read -p "Добавить в автозагрузку? (y/N): " add_autostart
    
    if [[ "$add_autostart" =~ ^[Yy]$ ]]; then
        case $OS in
            linux)
                AUTOSTART_FILE="$HOME/.config/autostart/screen-recorder.desktop"
                mkdir -p "$(dirname "$AUTOSTART_FILE")"
                cat > "$AUTOSTART_FILE" << EOF
[Desktop Entry]
Type=Application
Name=Screen Recorder
Exec=$PWD/recorder_manager.sh start
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
                echo -e "${GREEN}✓ Автозагрузка добавлена для Linux${NC}"
                ;;
            macos)
                AUTOSTART_FILE="$HOME/Library/LaunchAgents/com.screen.recorder.plist"
                cat > "$AUTOSTART_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.screen.recorder</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PWD/recorder_manager.sh</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
                echo -e "${GREEN}✓ Автозагрузка добавлена для macOS${NC}"
                ;;
        esac
    fi
}

show_final_message() {
    echo -e "\n${GREEN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${BLUE}Что установлено:${NC}"
    echo "  ✓ Зависимости: ffmpeg и другие утилиты"
    echo "  ✓ Настройки: сохранены в ~/.screen_recorder_config"
    echo "  ✓ Скрипты: screen_recorder.sh, recorder_manager.sh"
    echo ""
    
    echo -e "${BLUE}Как использовать:${NC}"
    echo "  ▶  Начать запись:   ./recorder_manager.sh start"
    echo "  ⏹  Остановить:      ./recorder_manager.sh stop"
    echo "  📊 Посмотреть статус: ./recorder_manager.sh status"
    echo "  📁 Открыть меню:     ./recorder_manager.sh"
    echo ""
    
    echo -e "${BLUE}Где записи:${NC}"
    echo "  ~/screen_recordings/"
    echo ""
    
    echo -e "${YELLOW}Хотите запустить запись сейчас? (y/N): ${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./recorder_manager.sh start
        echo -e "\n${GREEN}Запись запущена! Для управления используйте:${NC}"
        echo "  ./recorder_manager.sh"
    fi
}

main() {
    if [ "$EUID" -eq 0 ]; then 
        echo -e "${RED}Не запускайте скрипт от root!${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Шаг 1: Проверка и установка зависимостей${NC}"
    install_dependencies
    
    echo -e "${YELLOW}Шаг 2: Настройка параметров записи${NC}"
    
    echo -e "${YELLOW}Шаг 3: Создание рабочих скриптов${NC}"
    
    echo -e "${YELLOW}Шаг 4: Настройка автозапуска (опционально)${NC}"
    setup_autostart
    
    show_final_message
}

echo -e "\n${YELLOW}Очистка старых конфигураций...${NC}"
rm -f ~/.screen_recorder_config
rm -f ~/screen_recordings/.screen_recorder_config

create_scripts
setup_configuration

main
