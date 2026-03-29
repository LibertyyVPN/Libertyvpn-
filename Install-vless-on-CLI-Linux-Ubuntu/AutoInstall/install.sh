#!/bin/bash

set -e

SUB_URL="$1"
PY_SCRIPT_URL="https://raw.githubusercontent.com/libertyvpn/Libertyvpn-/main/Install-vless-on-CLI-Linux-Ubuntu/AutoInstall/main.py"
SINGBOX_CONFIG_URL="https://raw.githubusercontent.com/libertyvpn/Libertyvpn-/main/Install-vless-on-CLI-Linux-Ubuntu/AutoInstall/config.json"

CONFIG_DIR="/opt/vpn"
SINGBOX_CONFIG="$CONFIG_DIR/singbox.json"

echo "=== Обновление системы ==="
apt update
apt install -y curl wget python3 jq

echo "=== Установка Xray ==="
bash -c "$(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)"

echo "=== Установка sing-box ==="
wget -O /tmp/sing-box.deb https://github.com/SagerNet/sing-box/releases/download/v1.13.0/sing-box_1.13.0_linux_amd64.deb
dpkg -i /tmp/sing-box.deb

echo "=== Создание директории ==="
mkdir -p $CONFIG_DIR
cd $CONFIG_DIR

echo "=== Скачивание python скрипта ==="
wget -O main.py $PY_SCRIPT_URL
chmod +x main.py

echo "=== Генерация конфигов Xray ==="
python3 main.py --url $SUB_URL

echo "=== Поиск конфигов ==="
configs=($(ls config*.json))

if [ ${#configs[@]} -eq 0 ]; then
echo "Конфиги не найдены"
exit 1
fi

echo ""
echo "Доступные серверы:"
echo ""

i=1
for cfg in "${configs[@]}"; do
    country=$(jq -r '.remarks' $cfg)
    echo "$i) $country"
    ((i++))
done

echo ""
read -p "Выберите сервер: " choice

selected=${configs[$((choice-1))]}

if [ -z "$selected" ]; then
echo "Неверный выбор"
exit 1
fi

ln -sf $CONFIG_DIR/$selected $CONFIG_DIR/active.json

echo "=== Скачивание конфига sing-box ==="
wget -O $SINGBOX_CONFIG $SINGBOX_CONFIG_URL

echo "=== Создание systemd сервиса Xray ==="

cat <<EOF > /etc/systemd/system/xray-custom.service
[Unit]
Description=Xray VPN Client
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=5


[Service]
Type=simple
ExecStart=/usr/local/bin/xray run -config $XRAY_CONFIG
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "=== Создание systemd сервиса sing-box ==="

cat <<EOF > /etc/systemd/system/singbox-custom.service
[Unit]
Description=Sing-box TUN
After=network.target xray-custom.service
Requires=xray-custom.service
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
ExecStart=/usr/bin/sing-box run -c $SINGBOX_CONFIG
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "=== Перезагрузка systemd ==="
systemctl daemon-reexec
systemctl daemon-reload

echo "=== Включение сервисов ==="
systemctl enable xray-custom
systemctl enable singbox-custom

echo "=== Запуск ==="
systemctl restart xray-custom
sleep 2
systemctl restart singbox-custom

echo "=== Проверка IP ==="
curl https://api.ipify.org
echo ""

echo "=== Установка vpn-switch ==="

cat <<'EOF' > /usr/local/bin/vpn-switch
#!/bin/bash

CONFIG_DIR="/opt/vpn"

cd $CONFIG_DIR || exit

configs=($(ls config*.json))

if [ ${#configs[@]} -eq 0 ]; then
echo "Конфиги не найдены"
exit 1
fi

echo ""
echo "Доступные серверы:"
echo ""

i=1
for cfg in "${configs[@]}"; do
    server=$(jq -r '.remarks' $cfg)
    echo "$i) $server"
    ((i++))
done

echo ""
read -p "Выберите сервер: " choice

selected=${configs[$((choice-1))]}

if [ -z "$selected" ]; then
echo "Неверный выбор"
exit 1
fi

ln -sf $CONFIG_DIR/$selected $CONFIG_DIR/active.json

echo ""
echo "Перезапуск VPN..."

systemctl restart xray-vpn
sleep 2
systemctl restart singbox-vpn

echo ""
echo "Новый IP:"
curl https://api.ipify.org
echo ""
EOF

chmod +x /usr/local/bin/vpn-switch

echo "=== Готово ==="