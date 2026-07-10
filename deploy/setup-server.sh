#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-/opt/cardify}"
APP_USER="${CARDIFY_APP_USER:-cardify}"
SERVICE_NAME="${CARDIFY_SERVICE_NAME:-cardify-backend}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this one-time setup as root."
  exit 1
fi

apt-get update -y
apt-get install -y --no-install-recommends python3 python3-venv python3-pip curl rsync

if ! id -u "${APP_USER}" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "${APP_DIR}" --shell /usr/sbin/nologin "${APP_USER}"
fi

install -d -o "${APP_USER}" -g "${APP_USER}" "${APP_DIR}" "${APP_DIR}/backend" "${APP_DIR}/storage" "${APP_DIR}/deploy"

sed "s|__CARDIFY_APP_DIR__|${APP_DIR}|g" "${SCRIPT_DIR}/cardify-backend.service" > "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

echo "Server setup is ready. Create ${APP_DIR}/backend/.env from backend/.env.example before the first deployment."
