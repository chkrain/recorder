#!/bin/bash

SERVICE_FILE="/etc/systemd/system/screen-recorder.service"

cat > $SERVICE_FILE << EOF
[Unit]
Description=Screen Recorder Daemon
After=graphical.target

[Service]
Type=simple
User=$USER
Environment=DISPLAY=:0
WorkingDirectory=$HOME
ExecStart=$HOME/screen_recorder.sh
Restart=always
RestartSec=10
StandardOutput=append:$HOME/screen_recorder.log
StandardError=append:$HOME/screen_recorder.log

[Install]
WantedBy=graphical.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable screen-recorder
sudo systemctl start screen-recorder

echo "Сервис создан и запущен"
echo "Управление:"
echo "  sudo systemctl status screen-recorder"
echo "  sudo systemctl stop screen-recorder"
echo "  sudo systemctl start screen-recorder"
echo "  sudo journalctl -u screen-recorder -f"
