#!/bin/bash
#sudo apt-get update
#sudo apt-get install ffmpeg x11-utils
#sudo apt install vlc

RECORDINGS_DIR="$HOME/screen_recordings"
FPS=10
SEGMENT_DURATION=300  
MAX_DAYS=2

mkdir -p "$RECORDINGS_DIR"

timestamp() {
    date +"%Y%m%d_%H%M%S"
}

cleanup_old_files() {
    echo "[$(date)] Очистка файлов старше $MAX_DAYS дней..."
    find "$RECORDINGS_DIR" -name "screen_*.mp4" -type f -mtime +$MAX_DAYS -delete
    echo "[$(date)] Очистка завершена"
}

record_screen() {
    local segment_num=0
    
    while true; do
        local filename="screen_$(timestamp)_segment_${segment_num}.mp4"
        local filepath="$RECORDINGS_DIR/$filename"
        
        echo "[$(date)] Начало записи: $filename"
        
        ffmpeg -f x11grab \
               -video_size "$(xdpyinfo | grep dimensions | awk '{print $2}')" \
               -framerate $FPS \
               -i :0.0 \
               -t $SEGMENT_DURATION \
               -c:v libx264 \
               -preset ultrafast \
               -crf 28 \
               "$filepath" > /dev/null 2>&1
        
        echo "[$(date)] Завершена запись: $filename"
        
        segment_num=$((segment_num + 1))
        
        local current_hour=$(date +%H)
        if [ "$current_hour" = "03" ]; then
            cleanup_old_files
        fi
        
        sleep 1
    done
}

record_screen_mac() {
    local segment_num=0
    
    while true; do
        local filename="screen_$(timestamp)_segment_${segment_num}.mp4"
        local filepath="$RECORDINGS_DIR/$filename"
        
        echo "[$(date)] Начало записи: $filename"
        
        ffmpeg -f avfoundation \
               -capture_cursor 1 \
               -capture_mouse_clicks 1 \
               -i "1:none" \
               -t $SEGMENT_DURATION \
               -c:v libx264 \
               -preset ultrafast \
               -crf 28 \
               "$filepath" > /dev/null 2>&1
        
        echo "[$(date)] Завершена запись: $filename"
        
        segment_num=$((segment_num + 1))
        
        local current_hour=$(date +%H)
        if [ "$current_hour" = "03" ]; then
            cleanup_old_files
        fi
        
        sleep 1
    done
}

record_screen_windows() {
    echo "Для Windows рекомендуется использовать отдельный скрипт"
    echo "См. screen_recorder_windows.sh"
}

case "$(uname -s)" in
    Linux*)     record_screen ;;
    Darwin*)    record_screen_mac ;;
    CYGWIN*|MINGW*|MSYS*) 
                record_screen_windows
                exit 1 ;;
    *)          echo "Неподдерживаемая ОС"
                exit 1 ;;
esac
