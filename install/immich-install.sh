#!/usr/bin/env bash

# Copyright (c) 2024 chmistry
# Author: chmistry
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

#!/bin/bash

# Скрипт установки Immich в контейнере Proxmox
# Основан на репозитории https://github.com/loeeeee/immich-in-lxc

set -euo pipefail

# Базовая конфигурация
IMMICH_USER="immich"
IMMICH_DIR="/home/$IMMICH_USER"
UPLOAD_DIR="$IMMICH_DIR/upload"
REPO_URL="https://github.com/loeeeee/immich-in-lxc.git"
REPO_DIR="$IMMICH_DIR/immich-in-lxc"
LOG_DIR="/var/log/immich"
IMMICH_REPO_TAG="v1.132.3" # текущая стабильная версия
DB_PASSWORD="$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9')" # генерация безопасного пароля

# Определение версии Ubuntu/Debian
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
    msg_info "Обнаружена ОС: $OS $VERSION"
else
    msg_error "Невозможно определить версию ОС"
fi

# Проверка поддерживаемой версии ОС
if [ "$OS" = "ubuntu" ]; then
    if [ "$VERSION" != "24.04" ]; then
        msg_warn "Рекомендуется использовать Ubuntu 24.04, текущая версия: $VERSION"
    fi
    DEP_SCRIPT="dep-ubuntu.sh"
elif [ "$OS" = "debian" ]; then
    if [ "$VERSION" != "12" ]; then
        msg_warn "Рекомендуется использовать Debian 12, текущая версия: $VERSION"
    fi
    DEP_SCRIPT="dep-debian.sh"
else
    msg_error "Неподдерживаемая ОС: $OS"
fi

# Установка базовых зависимостей
msg_info "Установка базовых зависимостей..."
$STD apt install -y curl git python3-venv python3-dev build-essential unzip postgresql-common gnupg software-properties-common
msg_ok "Базовые зависимости установлены"

# Установка PostgreSQL с pgvector
msg_info "Установка PostgreSQL с расширением pgvector..."
$STD /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
$STD apt install -y postgresql-17 postgresql-17-pgvector
msg_ok "PostgreSQL установлен"

# Настройка базы данных
msg_info "Настройка базы данных PostgreSQL..."
$STD sudo -u postgres psql -c "CREATE DATABASE immich;"
$STD sudo -u postgres psql -c "CREATE USER immich WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"
$STD sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE immich to immich;"
$STD sudo -u postgres psql -c "ALTER USER immich WITH SUPERUSER;"
msg_ok "База данных настроена"

# Установка Redis
msg_info "Установка Redis..."
$STD apt install -y redis
msg_ok "Redis установлен"

# Установка FFmpeg от Jellyfin с поддержкой аппаратного ускорения
msg_info "Установка FFmpeg с поддержкой аппаратного ускорения..."
if [ "$OS" = "ubuntu" ]; then
    $STD apt install -y curl gnupg software-properties-common
    $STD add-apt-repository universe -y
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg
    export VERSION_OS="$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release )"
    export VERSION_CODENAME="$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release )"
    export DPKG_ARCHITECTURE="$( dpkg --print-architecture )"
    cat <<EOF | tee /etc/apt/sources.list.d/jellyfin.sources > /dev/null
Types: deb
URIs: https://repo.jellyfin.org/${VERSION_OS}
Suites: ${VERSION_CODENAME}
Components: main
Architectures: ${DPKG_ARCHITECTURE}
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF
elif [ "$OS" = "debian" ]; then
    $STD apt install -y curl gnupg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg
    export DPKG_ARCHITECTURE="$( dpkg --print-architecture )"
    cat <<EOF | tee /etc/apt/sources.list.d/jellyfin.sources > /dev/null
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: bookworm
Components: main
Architectures: ${DPKG_ARCHITECTURE}
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF
fi

$STD apt update
$STD apt install -y jellyfin-ffmpeg7
$STD ln -sf /usr/lib/jellyfin-ffmpeg/ffmpeg /usr/bin/ffmpeg
$STD ln -sf /usr/lib/jellyfin-ffmpeg/ffprobe /usr/bin/ffprobe
msg_ok "FFmpeg установлен"

# Создание пользователя Immich
msg_info "Создание пользователя Immich..."
$STD adduser --shell /bin/bash --disabled-password $IMMICH_USER --comment "Immich Mich" --gecos ""
$STD mkdir -p $UPLOAD_DIR
$STD chown -R $IMMICH_USER:$IMMICH_USER $IMMICH_DIR
msg_ok "Пользователь Immich создан"

# Установка Node.js через nvm для пользователя Immich
msg_info "Установка Node.js для пользователя Immich..."
$STD su - $IMMICH_USER -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash'
$STD su - $IMMICH_USER -c 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm install 22'
msg_ok "Node.js установлен"

# Клонирование репозитория immich-in-lxc
msg_info "Клонирование репозитория immich-in-lxc..."
$STD su - $IMMICH_USER -c "git clone $REPO_URL $REPO_DIR"
msg_ok "Репозиторий immich-in-lxc клонирован"

# Установка зависимостей для сборки библиотек обработки изображений
msg_info "Установка зависимостей для сборки библиотек обработки изображений..."
cd $REPO_DIR
$STD ./$DEP_SCRIPT
msg_ok "Зависимости для сборки установлены"

# Сборка библиотек обработки изображений
msg_info "Сборка библиотек обработки изображений (это может занять некоторое время)..."
$STD ./pre-install.sh
msg_ok "Библиотеки обработки изображений собраны"

# Создание .env файла
msg_info "Создание .env файла для установки Immich..."
cat > $REPO_DIR/.env << EOF
# Installation settings
REPO_TAG=$IMMICH_REPO_TAG
INSTALL_DIR=$IMMICH_DIR
UPLOAD_DIR=$UPLOAD_DIR
isCUDA=false
PROXY_NPM=
PROXY_NPM_DIST=
PROXY_POETRY=
EOF
msg_ok ".env файл создан"

# Запуск скрипта установки Immich
msg_info "Установка Immich..."
# su - $IMMICH_USER -c "cd $REPO_DIR && ./install.sh"
$STD su - $IMMICH_USER -c "export REPO_DIR='$REPO_DIR' && export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && cd \"\$REPO_DIR\" && ./install.sh"
# $STD sudo -u $IMMICH_USER bash -c "export REPO_DIR='$REPO_DIR' && export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && cd \"\$REPO_DIR\" && ./install.sh"
# $STD su - $IMMICH_USER -c 'export REPO_DIR='$REPO_DIR' && export NVM_DIR=$HOME/.nvm && [ -s $NVM_DIR/nvm.sh ] && . $NVM_DIR/nvm.sh && cd '$REPO_DIR' && ./install.sh'
# $STD sudo -u $IMMICH_USER bash -c 'export REPO_DIR='$REPO_DIR' && export NVM_DIR=$HOME/.nvm && [ -s $NVM_DIR/nvm.sh ] && . $NVM_DIR/nvm.sh && cd '$REPO_DIR' && ./install.sh'
msg_ok "Immich установлен"

# Настройка runtime.env
msg_info "Настройка runtime.env..."
sed -i "s/A_SEHR_SAFE_PASSWORD/$DB_PASSWORD/g" $IMMICH_DIR/runtime.env
sed -i "s|America/New_York|$(timedatectl show --property=Timezone --value)|g" $IMMICH_DIR/runtime.env
msg_ok "runtime.env настроен"

# Запуск post-install скрипта
msg_info "Выполнение post-install скрипта..."
cd $REPO_DIR
$STD ./post-install.sh
msg_ok "post-install скрипт выполнен"

# Создание директории для логов
msg_info "Создание директории для логов..."
mkdir -p $LOG_DIR
chown -R $IMMICH_USER:$IMMICH_USER $LOG_DIR
msg_ok "Директория для логов создана"

# Запуск служб Immich
msg_info "Запуск служб Immich..."
systemctl daemon-reload
systemctl enable --now immich-ml.service
systemctl enable --now immich-web.service
msg_ok "Службы Immich запущены"

# Проверка статуса служб
msg_info "Проверка статуса служб..."
systemctl status immich-ml.service --no-pager || true
systemctl status immich-web.service --no-pager || true
msg_ok "Статус служб проверен"

# Получение IP-адреса
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo -e "\n${DGN}=========================================${CL}"
echo -e "${DGN}Установка Immich успешно завершена!${CL}"
echo -e "${DGN}=========================================${CL}\n"

echo -e "Веб-интерфейс: ${BL}http://$IP_ADDRESS:2283${CL}"
echo -e "Пароль для базы данных: ${YW}$DB_PASSWORD${CL}"
echo -e "Файлы журналов: ${BL}$LOG_DIR${CL}"
echo -e "\n${YW}ВАЖНО: После первого входа в веб-интерфейс Immich${CL}"
echo -e "${YW}необходимо изменить URL для машинного обучения:${CL}"
echo -e "Зайдите в: Administration > Settings > Machine Learning Settings"
echo -e "Установите URL: ${BL}http://localhost:3003${CL}"
echo -e "\nДля проверки аппаратного ускорения транскодирования:"
echo -e "Зайдите в: Administration > Settings > Video Transcoding Settings"
echo -e "Выберите ваш метод аппаратного ускорения (NVENC, QuickSync и т.д.)"