#!/bin/bash

RECORDINGS_DIR="$HOME/screen_recordings"
mkdir -p "$RECORDINGS_DIR"

DURATION_MINUTES=1
FPS=5
CRF=28
RETENTION_HOURS=48

log() {
    echo "[$(date '+%d%m%Y-%H%M%S')] $1"
}

get_hour_folder() {
    local timestamp=$(date +"%d%m%y-%H")
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
