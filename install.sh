#!/usr/bin/env bash
# ============================================================
#  IRSupp v2ray Selling Bot installer (Docker edition)
#  Usage:  bash install.sh
# ============================================================
set -e
REPO="boroumandhosein/irsuppbot"
INSTALL_DIR="/opt/irsuppbot"
LICENSE_SERVER="https://bot.irsupp.ir"
PRODUCT="v2ray_bot"
echo "════════════════════════════════════════"
echo "    IRSupp v2ray Selling Bot - Installer"
echo "════════════════════════════════════════"
# 1) Install Docker if missing
if ! command -v docker >/dev/null 2>&1; then
    echo "> Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    echo "OK: Docker installed"
else
    echo "OK: Docker already present"
fi
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"
# 2) Collect info from user
echo ""
echo "─── Enter bot details ───"
read -rp "Bot token (from BotFather): " BOT_TOKEN
read -rp "Admin numeric ID(s) (comma separated): " ADMIN_IDS
read -rp "License key: " LICENSE_KEY
read -rp "Channel ID (optional, press Enter to skip): " CHANNEL_ID
read -rp "ZarinPal key (optional, press Enter to skip): " ZARINPAL_KEY
# Image version (default: latest)
read -rp "Version to install (Enter = latest): " VERSION
VERSION="${VERSION:-latest}"
IMAGE="${REPO}:${VERSION}"
echo "   -> Installing version: ${VERSION}"
DB_PASS="$(cat /proc/sys/kernel/random/uuid)"
HARDWARE_ID="$(cat /proc/sys/kernel/random/uuid)"
# 3) Create .env
cat > "${INSTALL_DIR}/.env" << EOF
BOT_TOKEN=${BOT_TOKEN}
ADMIN_IDS=${ADMIN_IDS}
CHANNEL_ID=${CHANNEL_ID}
LICENSE_KEY=${LICENSE_KEY}
LICENSE_SERVER=${LICENSE_SERVER}
PRODUCT=${PRODUCT}
ZARINPAL_KEY=${ZARINPAL_KEY}
DB_USER=postgres
DB_PASS=${DB_PASS}
DB_NAME=irsuppbot
HARDWARE_ID=${HARDWARE_ID}
IMAGE_TAG=${VERSION}
EOF
chmod 600 "${INSTALL_DIR}/.env"
# 4) Create docker-compose.yml
cat > "${INSTALL_DIR}/docker-compose.yml" << 'EOF'
services:
  db:
    image: postgres:16-alpine
    container_name: irsuppbot_db
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER:-postgres}
      POSTGRES_PASSWORD: ${DB_PASS}
      POSTGRES_DB: ${DB_NAME:-irsuppbot}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-postgres} -d ${DB_NAME:-irsuppbot}"]
      interval: 10s
      timeout: 5s
      retries: 5
  bot:
    image: boroumandhosein/irsuppbot:${IMAGE_TAG:-latest}
    container_name: irsuppbot_app
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      BOT_TOKEN: ${BOT_TOKEN}
      ADMIN_IDS: ${ADMIN_IDS}
      CHANNEL_ID: ${CHANNEL_ID}
      LICENSE_KEY: ${LICENSE_KEY}
      LICENSE_SERVER: ${LICENSE_SERVER}
      PRODUCT: ${PRODUCT:-v2ray_bot}
      HARDWARE_ID: ${HARDWARE_ID}
      ZARINPAL_KEY: ${ZARINPAL_KEY}
      DB_USER: ${DB_USER:-postgres}
      DB_PASS: ${DB_PASS}
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: ${DB_NAME:-irsuppbot}
    volumes:
      - botlogs:/app/logs
volumes:
  pgdata:
  botlogs:
EOF
# 5) Create update.sh (so the customer can update later)
cat > "${INSTALL_DIR}/update.sh" << 'EOF'
#!/usr/bin/env bash
# ============================================================
#  update.sh - update the bot to a newer version
#  Usage:  bash update.sh           (latest per .env)
#          bash update.sh v1.0.2     (specific version)
#  Database, settings and license are preserved.
# ============================================================
set -e
INSTALL_DIR="/opt/irsuppbot"
cd "${INSTALL_DIR}"
echo "════════════════════════════════════════"
echo "   IRSupp v2ray Selling Bot - Update"
echo "════════════════════════════════════════"
# If a version arg is given, store it in .env
if [ -n "$1" ]; then
    if grep -q '^IMAGE_TAG=' .env 2>/dev/null; then
        sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$1/" .env
    else
        echo "IMAGE_TAG=$1" >> .env
    fi
    echo "   -> Target version: $1"
else
    echo "   -> Target version: per .env (default latest)"
fi
echo "> Pulling image..."
docker compose pull bot
echo "> Starting new version..."
docker compose up -d
echo "> Pruning old images..."
docker image prune -f >/dev/null 2>&1 || true
echo ""
echo "════════════════════════════════════════"
echo "  Done! Update complete."
echo "  Database and settings preserved."
echo "  View logs:  docker compose logs -f bot"
echo "════════════════════════════════════════"
EOF
chmod +x "${INSTALL_DIR}/update.sh"
# 6) Pull and run
echo "> Pulling and starting the bot..."
docker pull "${IMAGE}"
docker compose up -d
echo ""
echo "════════════════════════════════════════"
echo "  Done! Installation complete. Send /start in Telegram."
echo "  Installed version: ${VERSION}"
echo "  Logs:     cd ${INSTALL_DIR} && docker compose logs -f bot"
echo "  Restart:  cd ${INSTALL_DIR} && docker compose restart bot"
echo "  Update:   cd ${INSTALL_DIR} && bash update.sh"
echo "════════════════════════════════════════"
