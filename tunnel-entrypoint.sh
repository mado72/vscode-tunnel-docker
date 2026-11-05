#!/bin/bash
# Entrypoint: Starts the tunnel using the persisted token (keychain file on the volume).
# If the token does not exist or has expired, the CLI itself displays the device code in the logs.
set -e


TUNNEL_NAME="${1:-vscode-tunnel-docker}"


# Token in a FILE (persisted on the volume) instead of the OS keychain.
# Source: microsoft/vscode-remote-release#8358
export VSCODE_CLI_USE_FILE_KEYCHAIN=1


echo "==> Starting tunnel '$TUNNEL_NAME'..."
exec /usr/local/bin/code tunnel \
  --name "$TUNNEL_NAME" \
  --accept-server-license-terms \
  --verbose
