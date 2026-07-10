#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${CARDIFY_APP_DIR:-/opt/cardify}"
APP_USER="${CARDIFY_APP_USER:-cardify}"
SERVICE_NAME="${CARDIFY_SERVICE_NAME:-cardify-backend}"
BACKEND_DIR="${APP_DIR}/backend"
DEPLOY_DIR="${APP_DIR}/deploy"

if [[ ! -f "${BACKEND_DIR}/.env" ]]; then
  echo "Missing ${BACKEND_DIR}/.env. Create it from backend/.env.example before deploying."
  exit 1
fi

sudo install -d -o "${APP_USER}" -g "${APP_USER}" "${APP_DIR}" "${APP_DIR}/storage"
sudo chown -R "${APP_USER}:${APP_USER}" "${BACKEND_DIR}" "${DEPLOY_DIR}"

if [[ ! -x "${BACKEND_DIR}/.venv/bin/python" ]]; then
  sudo -u "${APP_USER}" python3 -m venv "${BACKEND_DIR}/.venv"
fi

sudo -u "${APP_USER}" "${BACKEND_DIR}/.venv/bin/python" -m pip install --upgrade pip setuptools wheel --quiet
sudo -u "${APP_USER}" "${BACKEND_DIR}/.venv/bin/python" -m pip install --upgrade "${BACKEND_DIR}" --quiet

sudo sed "s|__CARDIFY_APP_DIR__|${APP_DIR}|g" "${DEPLOY_DIR}/cardify-backend.service" > "/etc/systemd/system/${SERVICE_NAME}.service"
sudo systemctl daemon-reload
sudo systemctl enable --now "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"

for _ in $(seq 1 30); do
  if curl --fail --silent http://127.0.0.1:8000/health >/dev/null; then
    echo "Cardify backend is healthy."
    exit 0
  fi
  sleep 1
done

sudo journalctl -u "${SERVICE_NAME}" --no-pager -n 60
exit 1
