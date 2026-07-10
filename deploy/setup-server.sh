#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-/opt/cardify}"
APP_USER="${CARDIFY_APP_USER:-cardify}"
RUNNER_USER="${CARDIFY_RUNNER_USER:-cardify-runner}"
RUNNER_DIR="${CARDIFY_RUNNER_DIR:-/opt/actions-runner/Cardify}"
SERVICE_NAME="${CARDIFY_SERVICE_NAME:-cardify-backend}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this one-time setup as root."
  exit 1
fi

apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl git python3 python3-venv python3-pip rsync sudo

if ! id -u "${APP_USER}" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "${APP_DIR}" --shell /usr/sbin/nologin "${APP_USER}"
fi

if ! id -u "${RUNNER_USER}" >/dev/null 2>&1; then
  useradd --create-home --home-dir "${RUNNER_DIR}" --shell /bin/bash "${RUNNER_USER}"
fi

install -d -o "${APP_USER}" -g "${APP_USER}" "${APP_DIR}" "${APP_DIR}/backend" "${APP_DIR}/storage"
install -d -o root -g root -m 755 "${APP_DIR}/deploy"
install -d -o "${RUNNER_USER}" -g "${RUNNER_USER}" "${RUNNER_DIR}"

install -o root -g "${RUNNER_USER}" -m 750 "${SCRIPT_DIR}/cardify-deploy" /usr/local/sbin/cardify-deploy
printf 'CARDIFY_APP_DIR=%q\nCARDIFY_RUNNER_DIR=%q\n' "${APP_DIR}" "${RUNNER_DIR}" > /etc/cardify-deploy.env
chmod 644 /etc/cardify-deploy.env
printf '%s\n' "${RUNNER_USER} ALL=(root) NOPASSWD: /usr/local/sbin/cardify-deploy" > /etc/sudoers.d/cardify-runner
chmod 440 /etc/sudoers.d/cardify-runner
visudo -cf /etc/sudoers.d/cardify-runner

sed "s|__CARDIFY_APP_DIR__|${APP_DIR}|g" "${SCRIPT_DIR}/cardify-backend.service" > "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload

echo "Server setup is ready. Create ${APP_DIR}/backend/.env, then run deploy/setup-github-runner.sh to register the self-hosted runner."
