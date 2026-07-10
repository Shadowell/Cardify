#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${CARDIFY_APP_DIR:-/opt/cardify}"
APP_USER="${CARDIFY_APP_USER:-cardify}"
SERVICE_NAME="${CARDIFY_SERVICE_NAME:-cardify-backend}"
SOURCE_DIR="${CARDIFY_SOURCE_DIR:?CARDIFY_SOURCE_DIR is required}"
DEPLOY_SHA="${CARDIFY_DEPLOY_SHA:?CARDIFY_DEPLOY_SHA is required}"
BACKEND_DIR="${APP_DIR}/backend"
DEPLOY_DIR="${APP_DIR}/deploy"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this deployment entrypoint as root."
  exit 1
fi

if [[ ! -f "${SOURCE_DIR}/backend/pyproject.toml" || ! -f "${SOURCE_DIR}/deploy/cardify-backend.service" ]]; then
  echo "${SOURCE_DIR} is not a Cardify deployment checkout."
  exit 1
fi

if [[ ! -f "${BACKEND_DIR}/.env" ]]; then
  echo "Missing ${BACKEND_DIR}/.env. Create it from backend/.env.example before deploying."
  exit 1
fi

install -d -o "${APP_USER}" -g "${APP_USER}" "${APP_DIR}" "${BACKEND_DIR}" "${APP_DIR}/storage"
install -d -o root -g root -m 755 "${DEPLOY_DIR}"

rsync -a --delete \
  --exclude='.env' \
  --exclude='.venv/' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='storage/' \
  "${SOURCE_DIR}/backend/" "${BACKEND_DIR}/"
rsync -a --delete \
  --exclude='last_deployed_sha' \
  "${SOURCE_DIR}/deploy/" "${DEPLOY_DIR}/"

chown -R "${APP_USER}:${APP_USER}" "${BACKEND_DIR}" "${APP_DIR}/storage"
chmod 750 "${DEPLOY_DIR}/backend-deploy.sh"

if [[ ! -x "${BACKEND_DIR}/.venv/bin/python" ]]; then
  runuser -u "${APP_USER}" -- python3 -m venv "${BACKEND_DIR}/.venv"
fi

runuser -u "${APP_USER}" -- "${BACKEND_DIR}/.venv/bin/python" -m pip install --upgrade pip setuptools wheel --quiet
runuser -u "${APP_USER}" -- "${BACKEND_DIR}/.venv/bin/python" -m pip install --upgrade "${BACKEND_DIR}" --quiet

sed "s|__CARDIFY_APP_DIR__|${APP_DIR}|g" "${DEPLOY_DIR}/cardify-backend.service" > "/tmp/${SERVICE_NAME}.service"
install -m 644 "/tmp/${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service"
rm -f "/tmp/${SERVICE_NAME}.service"

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"

for _ in $(seq 1 30); do
  if curl --fail --silent http://127.0.0.1:8000/health >/dev/null; then
    printf '%s\n' "${DEPLOY_SHA}" > "${DEPLOY_DIR}/last_deployed_sha"
    chmod 644 "${DEPLOY_DIR}/last_deployed_sha"
    echo "Cardify backend is healthy at ${DEPLOY_SHA}."
    exit 0
  fi
  sleep 1
done

journalctl -u "${SERVICE_NAME}" --no-pager -n 60
exit 1
