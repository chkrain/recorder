#!/bin/bash

echo "Остановка всех процессов записи..."
pkill -f "screen_recorder.sh"
pkill -f "ffmpeg.*x11grab"
pkill -f "ffmpeg.*avfoundation"

sleep 2

echo "Удаление PID файлов..."
rm -f /tmp/screen_recorder.pid
rm -f ~/screen_recordings/screen_recorder.pid

echo "Проверка оставшихся процессов..."
if pgrep -f "screen_recorder.sh" > /dev/null; then
    echo "Принудительная остановка..."
    pkill -9 -f "screen_recorder.sh"
fi

echo "Запуск новой записи..."
./recorder_manager.sh start
