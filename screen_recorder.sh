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
