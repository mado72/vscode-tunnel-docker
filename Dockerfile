# Modern VS Code + Copilot + Java 21 + Angular 21 in an Ubuntu 22.04 container (glibc 2.35).
FROM ubuntu:22.04

ARG TARGET_UID=1000
ARG TARGET_GID=1000
ARG TARGET_USER=dev
ARG DOCKER_GID=999

ENV DEBIAN_FRONTEND=noninteractive

# Base + ripgrep + OpenJDK 21 + dependências do Testcontainers (bubblewrap, socat)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates ripgrep openjdk-21-jdk-headless bubblewrap socat netcat-openbsd \
    libstdc++6 \
    libuuid1 \
    postgresql-client \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
      -o /tmp/google-chrome.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/google-chrome.deb \
    && google-chrome --version \
    && rm -f /tmp/google-chrome.deb \
    && rm -rf /var/lib/apt/lists/*

# Java 21 as the default for VS Code and terminals (JAVA_HOME inherited from the server)
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Configures the version of Chrome used by Karma tests and the Playwright chrome channel.
ENV CHROME_BIN=/usr/bin/google-chrome

# Node.js 22 (required by Angular 21: ^22.12.0 — and by Copilot CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# GitHub Copilot CLI + Angular CLI 21 (tag v21-lts)
RUN npm install -g @github/copilot @angular/cli@21

# Changes the cache key only when --update-vscode is used.
ARG VSCODE_UPDATE=0

# CLI code: static binary
RUN echo "VSCode update cache key: ${VSCODE_UPDATE}" >/dev/null \
    && curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64" \
      -o /tmp/vscode-cli.tar.gz \
    && tar -xzf /tmp/vscode-cli.tar.gz -C /usr/local/bin code \
    && rm /tmp/vscode-cli.tar.gz \
    && chmod +x /usr/local/bin/code

# Create a container user with the configured name, UID, and GID, and add it to the Docker group
RUN set -eu; \
    if [ "${TARGET_UID}" = "1000" ] && getent passwd ubuntu >/dev/null; then \
      userdel -r ubuntu; \
    fi; \
    if ! getent group "${TARGET_GID}" >/dev/null; then \
      groupadd -g "${TARGET_GID}" "${TARGET_USER}"; \
    fi; \
    if ! getent group "${DOCKER_GID}" >/dev/null; then \
      groupadd -g "${DOCKER_GID}" host-docker; \
    fi; \
    useradd -m -u "${TARGET_UID}" -g "${TARGET_GID}" -G "${DOCKER_GID}" -s /bin/bash "${TARGET_USER}" \
    && mkdir -p "/home/${TARGET_USER}/.vscode/cli" \
    && ln -s "/home/${TARGET_USER}/.vscode" "/home/${TARGET_USER}/.vscode-server" \
    && chown -R "${TARGET_UID}:${TARGET_GID}" "/home/${TARGET_USER}/.vscode" \
    && chown -h "${TARGET_UID}:${TARGET_GID}" "/home/${TARGET_USER}/.vscode-server"

COPY tunnel-entrypoint.sh /usr/local/bin/tunnel-entrypoint.sh
RUN chmod +x /usr/local/bin/tunnel-entrypoint.sh

USER ${TARGET_USER}
WORKDIR /home/workspace

RUN git config --global --add safe.directory /home/workspace

ENTRYPOINT ["/usr/local/bin/tunnel-entrypoint.sh"]
CMD ["vscode-tunnel-docker"]
