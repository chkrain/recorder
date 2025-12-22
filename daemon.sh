#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/screen_recorder.sh"
PID_FILE="$SCRIPT_DIR/screen_recorder.pid"
LOG_FILE="$SCRIPT_DIR/screen_recorder.log"

start_daemon() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "Демон уже запущен (PID: $(cat $PID_FILE))"
        return 1
    fi
    
    echo "Запуск демона..."
    nohup "$MAIN_SCRIPT" >> "$LOG_FILE" 2>&1 &
    PID=$!
    echo $PID > "$PID_FILE"
    echo "Демон запущен с PID: $PID"
    echo "Записи сохраняются в: $HOME/screen_recordings/"
    echo "Формат имен: DDMM-HHMM-rec_N.mp4 (например: 2212-1658-rec_0.mp4)"
    echo "Логи: tail -f $LOG_FILE"
}

stop_daemon() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Демон не запущен (PID файл не найден)"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    if kill -0 $PID 2>/dev/null; then
        echo "Остановка демона (PID: $PID)..."
        kill $PID
        sleep 2
        
        if kill -0 $PID 2>/dev/null; then
            echo "Принудительная остановка..."
            kill -9 $PID
        fi
        
        rm -f "$PID_FILE"
        echo "Демон остановлен"
    else
        echo "Демон не запущен (процесс не найден)"
        rm -f "$PID_FILE"
    fi
}

status_daemon() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 $PID 2>/dev/null; then
            echo "✓ Демон работает (PID: $PID)"
            echo "Время работы: $(ps -p $PID -o etime= 2>/dev/null || echo 'неизвестно')"
            echo "Записи: $HOME/screen_recordings/"
            echo "Формат имен: DDMM-HHMM-rec_N.mp4"
            echo "Логи: $LOG_FILE"
            echo "Последние строки лога:"
            tail -5 "$LOG_FILE" 2>/dev/null
        else
            echo "✗ Демон не работает (устаревший PID)"
            rm -f "$PID_FILE"
        fi
    else
        echo "✗ Демон не запущен"
    fi
}

restart_daemon() {
    stop_daemon
    sleep 2
    start_daemon
}

show_logs() {
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        echo "Файл логов не найден: $LOG_FILE"
    fi
}

case "$1" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        restart_daemon
        ;;
    status)
        status_daemon
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
