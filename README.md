# vscode-tunnel-docker - VS Code Remote Tunnel in Docker
Dockerized VS Code Remote Tunnel with Java 21, Node.js 22, Angular CLI, and GitHub Copilot.

## Components

The Docker image includes:

- Ubuntu 22.04
- VS Code CLI
- GitHub Copilot CLI
- OpenJDK 21
- Node.js 22
- Angular CLI 21
- Google Chrome Stable
- Git
- ripgrep
- PostgreSQL client
- OpenSSH client
- Testcontainers-related dependencies
- Access to the host Docker daemon through `/var/run/docker.sock`

## Main Files

```text
.
├── .env.runtime
├── Dockerfile
├── start-vscode-tunnel.sh
└── tunnel-entrypoint.sh
```

### `Dockerfile`

Defines the development environment, including Java, Node.js, Angular CLI, GitHub Copilot CLI, Google Chrome, and the VS Code CLI.

### `start-vscode-tunnel.sh`

The startup script is responsible for:

1. Validating the project directory.
2. Starting the Docker service on the host if necessary.
3. Creating the `workspace_network` Docker network if it does not exist.
4. Detecting the host username, UID, GID, and Docker group ID.
5. Building the Docker image with the host user's configuration.
6. Removing the previous container.
7. Creating and starting a new container.
8. Starting the Remote Tunnel with the specified name.

### `tunnel-entrypoint.sh`

This script is copied into the image during the build and configured as the container entrypoint.

Its specific behavior is not described in this README because its contents are outside the scope of the configuration documented here.

## Prerequisites

The host must provide:

- Docker.
- A functional Docker service.
- `sudo` permissions for Docker commands.
- Bash.
- `getent`.
- `whoami`.
- `id`.
- `sed`.

The following project directory must also exist:

```text
$HOME/repo
```

The Docker build context must contain:

```text
Dockerfile
tunnel-entrypoint.sh
```

## Environment Configuration

The startup script uses the following file:

```text
.env.runtime
```

This file is passed to the container through Docker's `--env-file` option.

Because the path is relative, the file must be available in the directory from which the script is executed.

Do not commit `.env.runtime`, credentials, or access tokens to the repository.

## Usage

Before the first execution, make the startup script executable:

```bash
chmod +x start-vscode-tunnel.sh
```

### Start the tunnel using the default name

```bash
./start-vscode-tunnel.sh
```

The default tunnel name is:

```text
vscode-tunnel-docker
```

### Start the tunnel with a custom name

```bash
./start-vscode-tunnel.sh my-tunnel
```

The tunnel will be started with the name:

```text
my-tunnel
```

### Update the VS Code CLI

To force the VS Code CLI binary to be downloaded again during the Docker image build:

```bash
./start-vscode-tunnel.sh --update-vscode
```

A custom tunnel name can also be specified:

```bash
./start-vscode-tunnel.sh --update-vscode my-tunnel
```

The arguments can also be provided in the opposite order:

```bash
./start-vscode-tunnel.sh my-tunnel --update-vscode
```

The `--update-vscode` option changes the Docker cache key for the VS Code CLI installation layer. This allows Docker to reuse the previous layers while forcing a new download of the VS Code CLI.

The download is performed from:

https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64


## Docker Image

The image is built with the following name:

```text
vscode-copilot-tunnel
```

The startup script passes the following host information to Docker:

- Username.
- UID.
- GID.
- Docker group ID.

This helps maintain compatible file ownership and permissions between the host and the container.

The image also receives the following build argument:

```text
VSCODE_UPDATE
```

Its default value in the `Dockerfile` is:

```text
0
```

When `--update-vscode` is used, the startup script passes a timestamp-based value. This invalidates the cache for the VS Code CLI installation layer.

## Container Configuration

The container uses the fixed name:

```text
vscode-copilot-tunnel
```

Before starting a new instance, the script removes any existing container with the same name.

Main container settings:

```text
Container name: vscode-copilot-tunnel
Hostname: vscode-tunnel
Network: workspace_network
Restart policy: always
Working directory: /home/workspace
Shared memory size: 256 MB
```

## Docker Network

The script ensures that the following Docker network exists:

```text
workspace_network
```

If the network does not exist, it is created automatically:

```bash
sudo docker network create workspace_network
```

## Runtime Environment Variables

The startup script passes the `.env.runtime` file to the container using Docker's `--env-file` option. Each `KEY=value` entry is made available to processes inside the container as an environment variable.

The application or service must read the corresponding variable names for them to affect its configuration. Add only variables that are expected by the application or its startup scripts; the example file does not define application-specific settings.

To create a local runtime file from the template:

```bash
cp .env.runtime.example .env.runtime
```

The container connects to this network to access other services through their Docker hostnames.

## Published Ports

The following ports are published only on the host loopback interface:

```text
127.0.0.1:4002:4002
127.0.0.1:8080:8080
```

This means that these services are accessible locally on the host but are not exposed directly on all network interfaces.

## Volumes

| Volume/Purpose | Host Path | Container Path | Access |
| --- | --- | --- | --- |
| Repository to save your code | `$HOME/repo` | `/home/workspace` | Read/write |
| VS Code data to save copilot artifacts | `$HOME/.vscode-docker-data` | `/home/<user>/.vscode` | Read/write |
| Copilot data to save sessions | `$HOME/.vscode-docker-data/copilot` | `/home/<user>/.copilot` | Read/write |
| Gradle data for cache libraries | `$HOME/.gradle-docker-data` | `/home/<user>/.gradle` | Read/write |
| SSH keys to reuse the same ssh settings | `$HOME/.ssh` | `/home/<user>/.ssh` | Read-only |
| Docker socket | `/var/run/docker.sock` | `/var/run/docker.sock` | Host Docker daemon access |
| Auxiliary scripts | `$HOME/bin/vscode-docker` | `/home/vscode-docker` | Read/write |

`<user>` represents the user configured in the container. The Docker socket provides access to the host's Docker daemon, subject to permissions.

## Container User

During the image build, the container user is created using the host user's values:

```text
TARGET_USER
TARGET_UID
TARGET_GID
```

The host Docker group is also registered in the image using:

```text
DOCKER_GID
```

This configuration helps reduce permission issues when accessing:

- Project files.
- VS Code data.
- Copilot data.
- Gradle cache.
- Docker socket.

## Viewing Container Logs

After starting the container, follow its logs with:

```bash
sudo docker logs -f vscode-copilot-tunnel
```

This is especially important during the first execution, when authentication for the Remote Tunnel may be required.

## Connecting from VS Code Desktop

After the container is running:

1. Open VS Code Desktop on Windows.
2. Open the **Remote Tunnels** functionality.
3. Locate the tunnel using the configured name.
4. Connect to the tunnel.

With the default configuration, look for:

```text
vscode-tunnel-docker
```

If a custom name was provided, search for the name used in the startup command.

## Updating the VS Code CLI

The VS Code CLI is not updated on every execution.

Normal execution:

```bash
./start-vscode-tunnel.sh
```

In this case, Docker may reuse the existing VS Code CLI layer from its cache.

Forced update:

```bash
./start-vscode-tunnel.sh --update-vscode
```

When this option is used:

1. The script generates a new cache key.
2. The VS Code CLI installation layer is invalidated.
3. The latest stable binary available from the configured endpoint is downloaded.
4. Previous Docker layers may still be reused.
5. The container is recreated using the updated image.

## Useful Commands

Check the container status:

```bash
sudo docker ps --filter name=vscode-copilot-tunnel
```

Follow the container logs:

```bash
sudo docker logs -f vscode-copilot-tunnel
```

Inspect the Docker image:

```bash
sudo docker images vscode-copilot-tunnel
```

Inspect the Docker network:

```bash
sudo docker network inspect workspace_network
```

Stop the container:

```bash
sudo docker stop vscode-copilot-tunnel
```

Remove the container:

```bash
sudo docker rm -f vscode-copilot-tunnel
```

## Complete Examples

### Standard startup

```bash
./start-vscode-tunnel.sh
```

### Startup with a custom tunnel name

```bash
./start-vscode-tunnel.sh java-project
```

### Update the VS Code CLI using the default tunnel name

```bash
./start-vscode-tunnel.sh --update-vscode
```

### Update the VS Code CLI with a custom tunnel name

```bash
./start-vscode-tunnel.sh java-project --update-vscode
```

## Troubleshooting

### The project directory does not exist

If the script reports that the project directory does not exist, verify that the following path is available on the host:

```text
$HOME/workspace
```

### The `.env.runtime` file cannot be found

Make sure that `.env.runtime` exists in the directory from which the startup script is executed.

### The tunnel does not appear in VS Code

Check the container logs:

```bash
sudo docker logs -f vscode-copilot-tunnel
```

The first execution may require authentication for the Remote Tunnel.

### Permission issues inside the container

Verify that:

- The host UID and GID are correctly detected.
- The Docker group exists on the host.
- The mounted directories are accessible by the current user.
- The Docker socket permissions allow access from the container user.

## Notes

- The container name is fixed as `vscode-copilot-tunnel`.
- Running the startup script again removes and recreates the container.
- The host project is mounted at `/home/workspace`.
- The default tunnel name is `vscode-tunnel-docker`.
- The `--update-vscode` option specifically invalidates the VS Code CLI download layer.
- Other Dockerfile layers remain eligible for normal Docker cache reuse.
- The `.env.runtime` file must be available in the script's working directory.
- Credentials and sensitive values should not be committed to the repository.
