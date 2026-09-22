# syntax=docker/dockerfile:1.7

FROM debian:trixie-slim AS base

ARG GO_VERSION=

ENV DEBIAN_FRONTEND=noninteractive \
    GOROOT=/usr/local/go \
    GOPATH=/root/go \
    PATH=/usr/local/go/bin:/root/go/bin:/root/.local/bin:$PATH \
    CGO_ENABLED=1 \
    COLORTERM=truecolor

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential pkg-config make \
        clang lld llvm \
        ca-certificates curl git xz-utils unzip less \
        jq ripgrep fd-find python3 python3-pip \
        gdb strace lsof \
        libsqlite3-dev zlib1g-dev \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s "$(command -v fdfind)" /usr/local/bin/fd \
 && pip3 install --break-system-packages --no-cache-dir semgrep

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

RUN set -eu; \
    go install honnef.co/go/tools/cmd/staticcheck@latest; \
    go install golang.org/x/vuln/cmd/govulncheck@latest; \
    go install golang.org/x/tools/cmd/goimports@latest; \
    go install golang.org/x/tools/gopls@latest; \
    go install mvdan.cc/gofumpt@latest; \
    go install github.com/securego/gosec/v2/cmd/gosec@latest; \
    go install github.com/go-delve/delve/cmd/dlv@latest; \
    go install gotest.tools/gotestsum@latest; \
    curl -fsSL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
        | sh -s -- -b /usr/local/bin; \
    go clean -cache -modcache -testcache

# Preserve PATH in login shells.
RUN printf 'export PATH=%s\n' "$PATH" > /etc/profile.d/10-path.sh

FROM base AS tooling
COPY harness/common-packages.txt /tmp/common-packages.txt
RUN apt-get update \
 && xargs -r apt-get install -y --no-install-recommends < /tmp/common-packages.txt \
 && rm -rf /var/lib/apt/lists/* /tmp/common-packages.txt

FROM tooling AS claude

ARG CLAUDE_INSTALL_BUST=0
RUN : "${CLAUDE_INSTALL_BUST}" \
 && curl -fsSL https://claude.ai/install.sh | bash

COPY harness/claude.json /root/.claude.json
COPY harness/claude-settings.json /root/.claude/settings.json
COPY go/container-rules.md /root/.claude/CLAUDE.md

# IS_SANDBOX=1 lets --dangerously-skip-permissions run as root.
ENV CLAUDE_CODE_OAUTH_TOKEN="" \
    GH_TOKEN="" \
    IS_SANDBOX=1
WORKDIR /workspace

CMD ["claude", "--dangerously-skip-permissions", "--effort", "xhigh"]

FROM tooling AS codex

ARG CODEX_INSTALL_BUST=0
ARG CODEX_VERSION=
RUN set -eu; \
    : "${CODEX_INSTALL_BUST}"; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) target=x86_64-unknown-linux-musl ;; \
        arm64) target=aarch64-unknown-linux-musl ;; \
        *) echo "codex: unsupported arch $arch" >&2; exit 1 ;; \
    esac; \
    tag="${CODEX_VERSION:-$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest | jq -r .tag_name)}"; \
    case "$tag" in rust-v*) ;; v*) tag="rust-${tag}" ;; *) tag="rust-v${tag}" ;; esac; \
    curl -fsSL "https://github.com/openai/codex/releases/download/${tag}/codex-package-${target}.tar.gz" \
        | tar xz --no-same-owner -C /usr/local; \
    codex --version; \
    test -x /usr/local/bin/codex-code-mode-host

COPY harness/codex-config.toml /root/.codex/config.toml
COPY go/container-rules.md /root/.codex/AGENTS.md

ENV CODEX_ACCESS_TOKEN="" \
    CODEX_AUTH_JSON="" \
    GH_TOKEN=""
WORKDIR /workspace

COPY --chmod=755 harness/codex-entrypoint /usr/local/bin/codex-entrypoint
ENTRYPOINT ["/usr/local/bin/codex-entrypoint"]

CMD ["codex", "--yolo"]
