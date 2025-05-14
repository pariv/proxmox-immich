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

msg_info "Installing Dependencies"
$STD apt install -y curl
$STD apt install -y git
$STD apt install -y python3-venv
$STD apt install -y python3-dev
$STD apt install -y build-essential
$STD apt install -y unzip
$STD apt install -y postgresql-common
$STD apt install -y gnupg
$STD apt install -y software-properties-common
$STD apt install -y redis
$STD apt install -y jq
msg_ok "Installed Dependencies"

msg_info "Installing Postgresql and pgvector"
$STD /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
$STD apt install -y postgresql postgresql-17-pgvector
msg_ok "Installed Postgresql and pgvector"

msg_info "Setting up database"
$STD sudo -u postgres psql -c "CREATE DATABASE immich;"
$STD sudo -u postgres psql -c "CREATE USER immich WITH ENCRYPTED PASSWORD 'YUaaWZAvtL@JpNgpi3z6uL4MmDMR_w';"
$STD sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE immich to immich;"
$STD sudo -u postgres psql -c "ALTER USER immich WITH SUPERUSER;"
msg_ok "Database setup completed"

msg_info "Installing ffmpeg jellyfin"
$STD add-apt-repository universe -y
$STD mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg
$STD export VERSION_OS="$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release )"
$STD export VERSION_CODENAME="$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release )"
$STD export DPKG_ARCHITECTURE="$( dpkg --print-architecture )"
cat <<EOF | tee /etc/apt/sources.list.d/jellyfin.sources
Types: deb
URIs: https://repo.jellyfin.org/${VERSION_OS}
Suites: ${VERSION_CODENAME}
Components: main
Architectures: ${DPKG_ARCHITECTURE}
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF
$STD apt update

$STD apt install -y jellyfin-ffmpeg7

ln -s /usr/lib/jellyfin-ffmpeg/ffmpeg /usr/bin/ffmpeg
ln -s /usr/lib/jellyfin-ffmpeg/ffprobe /usr/bin/ffprobe
msg_ok "Installed ffmpeg jellyfin"

msg_info "Adding immich user"
$STD adduser --shell /bin/bash --disabled-password immich --comment "Immich Mich"
msg_ok "User immich added"

msg_info "Installing Node.js and cloning repository"
su - immich -s /usr/bin/bash <<'IMMICH_EOF'
set -euo pipefail

# Установка nvm и Node.js 22
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
nvm install 22
cd ~
git clone https://github.com/loeeeee/immich-in-lxc.git
cd immich-in-lxc
IMMICH_EOF
msg_ok "Installed Node.js and cloned repository"

msg_info "Running pre-install script as root"
cd /home/immich/immich-in-lxc/
./pre-install.sh || {
    echo "pre-install failed, aborting." >&2
    exit 1
}
msg_ok "Pre-install completed"

msg_info "Installing Immich"
su - immich -s /usr/bin/bash <<'INSTALL_EOF'
set -euo pipefail
cd ~/immich-in-lxc

# First run to generate .env file
./install.sh || {
    echo "first install failed" >&2
    exit 1
}

# Настройка пароля в runtime.env
sed -i 's/A_SEHR_SAFE_PASSWORD/YUaaWZAvtL@JpNgpi3z6uL4MmDMR_w/g' runtime.env

# Финальный запуск install.sh
./install.sh || {
    echo "install.sh failed after configuration" >&2
    exit 1
}
INSTALL_EOF
msg_ok "Installed Immich"

msg_info "Running post-install script as root"
cd /home/immich/immich-in-lxc/
./post-install.sh || {
    echo "post-install failed, aborting." >&2
    exit 1
}
msg_ok "Post-install completed"

msg_info "Creating log directory /var/log/immich"
mkdir -p /var/log/immich
chown immich:immich /var/log/immich
msg_ok "Log directory created"

msg_info "Starting Immich services"
systemctl daemon-reload
systemctl restart immich-ml.service
systemctl restart immich-web.service
msg_ok "Started Immich services"

msg_info "Configuration note"
echo "Immich установлен и запущен. Веб-интерфейс доступен на порту 2283."
echo "Для корректной работы ML требуется настроить URL в администраторской панели:"
echo "Administration > Settings > Machine Learning Settings > URL: http://localhost:3003"
msg_ok "Configuration note displayed"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

