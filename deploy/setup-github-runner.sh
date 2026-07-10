#!/usr/bin/env bash
set -euo pipefail

RUNNER_USER="${CARDIFY_RUNNER_USER:-cardify-runner}"
RUNNER_DIR="${CARDIFY_RUNNER_DIR:-/opt/cardify-runner}"
RUNNER_REPOSITORY="${GITHUB_RUNNER_REPOSITORY:-Shadowell/Cardify}"
RUNNER_NAME="${GITHUB_RUNNER_NAME:-cardify-production}"
RUNNER_LABEL="${GITHUB_RUNNER_LABEL:-cardify-production}"
RUNNER_TOKEN="${GITHUB_RUNNER_TOKEN:?Set GITHUB_RUNNER_TOKEN to the one-hour GitHub runner registration token}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this one-time setup as root."
  exit 1
fi

if ! id -u "${RUNNER_USER}" >/dev/null 2>&1; then
  echo "Run deploy/setup-server.sh before registering the runner."
  exit 1
fi

if [[ -f "${RUNNER_DIR}/.runner" ]]; then
  echo "A runner is already registered in ${RUNNER_DIR}. Remove it through GitHub before registering a replacement."
  exit 1
fi

runner_version="$(curl --fail --silent --show-error https://api.github.com/repos/actions/runner/releases/latest | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"].removeprefix("v"))')"
runner_archive="actions-runner-linux-x64-${runner_version}.tar.gz"
runner_url="https://github.com/actions/runner/releases/download/v${runner_version}/${runner_archive}"

install -d -o "${RUNNER_USER}" -g "${RUNNER_USER}" "${RUNNER_DIR}"
runuser -u "${RUNNER_USER}" -- curl --fail --location --retry 3 --output "/tmp/${runner_archive}" "${runner_url}"
runuser -u "${RUNNER_USER}" -- tar xzf "/tmp/${runner_archive}" -C "${RUNNER_DIR}"
rm -f "/tmp/${runner_archive}"

"${RUNNER_DIR}/bin/installdependencies.sh"
runuser -u "${RUNNER_USER}" -- bash -c "cd '${RUNNER_DIR}' && ./config.sh --unattended --url 'https://github.com/${RUNNER_REPOSITORY}' --token '${RUNNER_TOKEN}' --name '${RUNNER_NAME}' --labels '${RUNNER_LABEL}' --work _work --replace"
"${RUNNER_DIR}/svc.sh" install "${RUNNER_USER}"
"${RUNNER_DIR}/svc.sh" start

echo "Runner ${RUNNER_NAME} is registered with label ${RUNNER_LABEL}."
