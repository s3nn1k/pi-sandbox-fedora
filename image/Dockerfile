
FROM golang:1.25-bookworm AS gotools
ARG GOOSE_VERSION=v3.28.0
ARG OAPI_VERSION=v2.8.0
ARG GOVERTER_VERSION=v1.11.0
ARG REVIVE_VERSION=v1.16.0
ARG GOLANGCI_VERSION=v2.13.2
ENV GOBIN=/out GOTOOLCHAIN=auto
RUN go install github.com/pressly/goose/v3/cmd/goose@${GOOSE_VERSION} \
 && go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@${OAPI_VERSION} \
 && go install github.com/jmattheis/goverter/cmd/goverter@${GOVERTER_VERSION} \
 && go install github.com/mgechev/revive@${REVIVE_VERSION} \
 && go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@${GOLANGCI_VERSION}

FROM debian:bookworm-slim AS whisper
ARG WHISPER_VERSION=v1.9.4
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential clang-14 clang++-14 cmake git ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && git clone --depth 1 --branch ${WHISPER_VERSION} https://github.com/ggml-org/whisper.cpp /src \
 && CC=clang-14 CXX=clang++-14 cmake -S /src -B /src/build -DWHISPER_BUILD_TESTS=OFF -DGGML_NATIVE=ON -DGGML_CPU_ALL_VARIANTS=OFF -DBUILD_SHARED_LIBS=OFF \
 && cmake --build /src/build --target whisper-cli -j"$(nproc)"

FROM node:24-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash git make ripgrep fd-find jq curl ca-certificates openssh-client socat \
      postgresql-client ffmpeg unzip xz-utils procps \
      fontconfig fonts-liberation fonts-dejavu-core fonts-noto-core fonts-noto-color-emoji \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd

COPY --from=gotools /usr/local/go /usr/local/go
COPY --from=gotools /out/ /usr/local/bin/
ENV GOPATH=/go GOTOOLCHAIN=auto
ENV PATH=/usr/local/go/bin:/go/bin:$PATH

COPY --from=whisper /src/build/bin/whisper-cli /usr/local/bin/

COPY --from=docker:29-cli /usr/local/bin/docker /usr/local/bin/docker

ARG AGENT_HOME_PATH
ARG AGENT_UID=1000
ARG AGENT_GID=1000
ARG COMPOSE_VERSION=v2.39.4
ARG COMPOSE_SHA256=7af95166a730b87e172d4fc9aefea8725d3c6c7327d59149267b452114ddb7d4
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose \
    && echo "${COMPOSE_SHA256}  /usr/local/lib/docker/cli-plugins/docker-compose" | sha256sum -c - \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
    && ln -s /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

ARG GLAB_VERSION=1.117.0
ARG GH_VERSION=2.100.0
ARG KUBECTL_VERSION=v1.37.0
ARG YQ_VERSION=v4.53.6
ARG YTDLP_VERSION=2026.08.19
ARG NVIM_VERSION=v0.12.5
ARG UV_VERSION=0.13.5
RUN set -eux; \
    curl -fsSL -o /tmp/glab.tgz \
      "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_amd64.tar.gz"; \
    tar -xzf /tmp/glab.tgz -C /tmp; \
    mv /tmp/bin/glab /usr/local/bin/glab; \
    curl -fsSL -o /tmp/gh.tgz \
      "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz"; \
    tar -xzf /tmp/gh.tgz -C /tmp; \
    mv "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh; \
    curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; \
    chmod +x /usr/local/bin/kubectl; \
    curl -fsSL -o /usr/local/bin/yq \
      "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"; \
    chmod +x /usr/local/bin/yq; \
    curl -fsSL -o /usr/local/bin/yt-dlp \
      "https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP_VERSION}/yt-dlp_linux_x86_64"; \
    chmod +x /usr/local/bin/yt-dlp; \
    curl -fsSL -o /tmp/nvim.tgz \
      "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"; \
    tar -xzf /tmp/nvim.tgz -C /opt; \
    ln -s /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim; \
    curl -fsSL -o /tmp/uv.tgz \
      "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz"; \
    tar -xzf /tmp/uv.tgz -C /tmp; \
    mv /tmp/uv-x86_64-unknown-linux-gnu/uv /tmp/uv-x86_64-unknown-linux-gnu/uvx /usr/local/bin/; \
    rm -rf /tmp/glab.tgz /tmp/gh.tgz /tmp/nvim.tgz /tmp/uv.tgz /tmp/bin /tmp/uv-x86_64-unknown-linux-gnu "/tmp/gh_${GH_VERSION}_linux_amd64"

ARG PLAYWRIGHT_VERSION=1.63.0
ENV PLAYWRIGHT_BROWSERS_PATH=/usr/local/share/ms-playwright \
    NODE_PATH=/usr/local/lib/node_modules
RUN npm install -g --ignore-scripts playwright@${PLAYWRIGHT_VERSION} \
 && apt-get update \
 && playwright install --with-deps chromium \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/pi-entrypoint
RUN chmod +x /usr/local/bin/pi-entrypoint

ENV GOCACHE=/tmp/gocache
ENV GOSUMDB=off
RUN mkdir -p /go/pkg/sumdb && chmod -R 0777 /go/pkg

RUN [ -n "$AGENT_HOME_PATH" ] || { echo "AGENT_HOME_PATH build-arg обязателен" >&2; exit 1; } \
    && mkdir -p ${AGENT_HOME_PATH}/.docker ${AGENT_HOME_PATH}/.local ${AGENT_HOME_PATH}/.cache ${AGENT_HOME_PATH}/.config \
    && chown -R ${AGENT_UID}:${AGENT_GID} ${AGENT_HOME_PATH}

ENTRYPOINT ["pi-entrypoint"]
