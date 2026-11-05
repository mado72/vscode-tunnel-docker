#!/bin/bash
# Start the VS Code + Copilot container on docker container.
# Usage: ./start-vscode-tunnel.sh [tunnel-name]
set -euo pipefail

TUNNEL_NAME="vscode-tunnel-docker"
TUNNEL_NAME_SET=false
UPDATE_VSCODE=false

for arg in "$@"; do
    case "$arg" in
        --update-vscode)
            UPDATE_VSCODE=true
            ;;
        -*)
            echo "ERROR: unknown option: ${arg}"
            echo "Uso: $0 [nome-do-tunel] [--update-vscode]"
            exit 1
            ;;
        *)
            if [ "$TUNNEL_NAME_SET" = true ]; then
                echo "ERROR: Only one tunnel name can be specified."
                echo "Usage: $0 [tunnel-name] [--update-vscode]"
                exit 1
            fi

            TUNNEL_NAME="$arg"
            TUNNEL_NAME_SET=true
            ;;
    esac
done

IMAGE_NAME="vscode-copilot-tunnel"
CONTAINER_NAME="vscode-copilot-tunnel"
SCRIPT_DIR="$HOME/bin/vscode-docker"
DATA_DIR="$HOME/.vscode-docker-data"
GRADLE_DATA_DIR="$HOME/.gradle-docker-data"
REPO_DIR="$HOME/repo"
ENV_FILE=".env.runtime"

mkdir -p "$DATA_DIR"
mkdir -p "$GRADLE_DATA_DIR"

[ -d "$REPO_DIR" ] || { echo "ERROR: $REPO_DIR does not exists."; exit 1; }
mkdir -p "$DATA_DIR"

# 1) Ensure that the 'workspace_network' network exists on the host before starting the container
if ! sudo docker network inspect workspace_network >/dev/null 2>&1; then
    echo "==> Creating the Docker network 'workspace_network'..."
    sudo docker network create workspace_network
fi

# 2) Daemon activated?
sudo service docker status >/dev/null 2>&1 || sudo service docker start

# 3) Retrieving and sanitizing the host user
TARGET_USER="dev"
TARGET_UID="$(id -u)"
TARGET_GID="$(id -g)"
DOCKER_GID="$(getent group docker | cut -d: -f3 || echo "999")"

echo "==> Building the image (User: ${TARGET_USER}, UID: ${TARGET_UID}, GID: ${TARGET_GID}, Docker GID: ${DOCKER_GID})..."

BUILD_ARGS=(
  --build-arg "TARGET_USER=${TARGET_USER}"
  --build-arg "TARGET_UID=${TARGET_UID}"
  --build-arg "TARGET_GID=${TARGET_GID}"
  --build-arg "DOCKER_GID=${DOCKER_GID}"
  -t "${IMAGE_NAME}"
)

if [ "$UPDATE_VSCODE" = true ]; then
    echo "==> Forcing the VS Code CLI to update..."
    BUILD_ARGS+=(--build-arg "VSCODE_UPDATE=$(date +%s)")
fi

sudo docker build \
  "${BUILD_ARGS[@]}" \
  "$(cd "$(dirname "$0")" && pwd)"

# 4) Remove the old container and deploy the new one to the 'workspace_network'
sudo docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
sudo docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart always \
  --network workspace_network \
  --hostname vscode-tunnel \
  --shm-size=256m \
  -p 127.0.0.1:4002:4002 \
  -p 127.0.0.1:8080:8080 \
  --env-file "${ENV_FILE}" \
  -e VSCODE_CLI_USE_FILE_KEYCHAIN=1 \
  -e GRADLE_USER_HOME="/home/${TARGET_USER}/.gradle" \
  -v "${REPO_DIR}":/home/workspace \
  -v "${DATA_DIR}":"/home/${TARGET_USER}/.vscode" \
  -v "${DATA_DIR}/copilot":"/home/${TARGET_USER}/.copilot" \
  -v "${GRADLE_DATA_DIR}":"/home/${TARGET_USER}/.gradle" \
  -v ~/.ssh:"/home/${TARGET_USER}/.ssh":ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${SCRIPT_DIR}":/home/vscode-docker \
  --group-add "${DOCKER_GID}" \
  -w /home/workspace \
  "${IMAGE_NAME}" "${TUNNEL_NAME}"

echo ""
echo "==> Container '${CONTAINER_NAME}' is running."
echo "==> First time: monitor the login with:"
echo " sudo docker logs -f ${CONTAINER_NAME}"
echo "==> Afterward: VS Code Desktop on Windows -> Remote Tunnels -> '${TUNNEL_NAME}'"
