# syntax=docker/dockerfile:1.7

FROM debian:trixie-slim AS base

ARG GO_VERSION=

ENV DEBIAN_FRONTEND=noninteractive \
    GOROOT=/usr/local/go \
    GOPATH=/root/go \
    PATH=/usr/local/go/bin:/root/go/bin:/root/.local/bin:$PATH \
    CGO_ENABLED=1 \
    COLORTERM=truecolor

COPY harness/base-packages.txt go/build-packages.txt /tmp/packages/
RUN apt-get update \
 && cat /tmp/packages/*.txt | xargs -r apt-get install -y --no-install-recommends \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && ln -s "$(command -v fdfind)" /usr/local/bin/fd \
 && pip3 install --break-system-packages --no-cache-dir semgrep \
 && rm -rf /var/lib/apt/lists/* /tmp/packages

RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) goarch=amd64 ;; \
        arm64) goarch=arm64 ;; \
        *) echo "go: unsupported arch $arch" >&2; exit 1 ;; \
    esac; \
    ver="${GO_VERSION:-$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)}"; \
    file="${ver}.linux-${goarch}.tar.gz"; \
    sha="$(curl -fsSL 'https://go.dev/dl/?mode=json&include=all' \
        | jq -er --arg v "$ver" --arg f "$file" \
            'map(select(.version == $v)) | first | .files[] | select(.filename == $f) | .sha256')"; \
    curl -fsSL -o /tmp/go.tar.gz "https://go.dev/dl/${file}"; \
    echo "${sha}  /tmp/go.tar.gz" | sha256sum -c -; \
    tar -C /usr/local -xzf /tmp/go.tar.gz; \
    rm /tmp/go.tar.gz; \
    go version

ENV GOTOOLCHAIN=auto

RUN --mount=type=cache,target=/root/.cache/go-build,sharing=locked \
    --mount=type=cache,target=/root/go/pkg/mod,sharing=locked \
    set -eu; \
    go install honnef.co/go/tools/cmd/staticcheck@latest; \
    go install golang.org/x/vuln/cmd/govulncheck@latest; \
    go install golang.org/x/tools/cmd/goimports@latest; \
    go install golang.org/x/tools/gopls@latest; \
    go install mvdan.cc/gofumpt@latest; \
    go install github.com/securego/gosec/v2/cmd/gosec@latest; \
    go install github.com/go-delve/delve/cmd/dlv@latest; \
    go install gotest.tools/gotestsum@latest; \
    curl -fsSL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
        | sh -s -- -b /usr/local/bin

# Preserve PATH in login shells.
RUN printf 'export PATH=%s\n' "$PATH" > /etc/profile.d/10-path.sh
