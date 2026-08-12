# syntax=docker/dockerfile:1.7

FROM debian:bookworm-slim AS base

# Pin to e.g. go1.25.0 for a reproducible image.
ARG GO_VERSION=

ENV DEBIAN_FRONTEND=noninteractive \
    GOROOT=/usr/local/go \
    GOPATH=/root/go \
    PATH=/usr/local/go/bin:/root/go/bin:/root/.local/bin:$PATH \
    CGO_ENABLED=1 \
    COLORTERM=truecolor

# Toolchain. gcc is needed for cgo and `go test -race`; clang for the
# `-msan` / `-asan` build modes, which Go only supports under clang.
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

# Go toolchain from the official tarball — bookworm's packaged go is far
# too old. The checksum comes from the same release index that lists the
# tarball, so this verifies transport/mirror integrity, not provenance.
RUN set -eux; \
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

# GOTOOLCHAIN=auto (the default) lets `go` fetch whatever toolchain a
# project's go.mod demands, so /workspace builds even when it needs a
# newer or older Go than the one baked in here.
ENV GOTOOLCHAIN=auto

# Analysis / QA tooling. golangci-lint comes from its install script
# because its module path moves between major versions.
RUN set -eux; \
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

# A login shell (`bash -lc`) re-sets PATH from /etc/profile and drops
# everything ENV added. Codex runs commands that way; re-export it.
RUN printf 'export PATH=%s\n' "$PATH" > /etc/profile.d/10-path.sh

FROM base AS claude

# build.sh sets CLAUDE_INSTALL_BUST to today's date by default, so this
# layer (and everything below it) refreshes once per day. Pass a different
# value (or use --no-cache) to force a mid-day refresh.
ARG CLAUDE_INSTALL_BUST=0
RUN echo "claude install bust=${CLAUDE_INSTALL_BUST}" \
 && curl -fsSL https://claude.ai/install.sh | bash

RUN printf '%s' '{"hasCompletedOnboarding":true,"hasTrustDialogAccepted":true,"hasTrustDialogHooksAccepted":true,"projects":{"/workspace":{"hasTrustDialogAccepted":true,"hasTrustDialogHooksAccepted":true}}}' \
    > /root/.claude.json

RUN mkdir -p /root/.claude && cat > /root/.claude/settings.json <<'JSON'
{
  "model": "claude-opus-4-8",
  "theme": "dark",
  "effortLevel": "xhigh",
  "tui": "default",
  "skipDangerousModePermissionPrompt": true,
  "awaySummaryEnabled": false,
  "spinnerTipsEnabled": false,
  "spinnerVerbs": {
    "mode": "replace",
    "verbs": ["Thinking"]
  }
}
JSON

COPY container-rules.md /root/.claude/CLAUDE.md

# Tokens injected at run time (-e). gh reads GH_TOKEN directly, no `gh auth
# login`; empty default = logged out. IS_SANDBOX=1 lets
# --dangerously-skip-permissions run as root.
ENV CLAUDE_CODE_OAUTH_TOKEN="" \
    GH_TOKEN="" \
    IS_SANDBOX=1
WORKDIR /workspace

CMD ["claude", "--dangerously-skip-permissions", "--effort", "xhigh"]

FROM base AS codex

# Static musl binary, so the npm package (and Node with it) is not needed.
ARG CODEX_INSTALL_BUST=0
ARG CODEX_VERSION=
RUN set -eux; \
    echo "codex install bust=${CODEX_INSTALL_BUST}"; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) target=x86_64-unknown-linux-musl ;; \
        arm64) target=aarch64-unknown-linux-musl ;; \
        *) echo "codex: unsupported arch $arch" >&2; exit 1 ;; \
    esac; \
    tag="${CODEX_VERSION:-$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest | jq -r .tag_name)}"; \
    mkdir -p /tmp/codex-dl; \
    curl -fsSL "https://github.com/openai/codex/releases/download/${tag}/codex-${target}.tar.gz" \
        | tar xz -C /tmp/codex-dl; \
    install -m 0755 "$(find /tmp/codex-dl -type f -name 'codex*' | head -n1)" /usr/local/bin/codex; \
    rm -rf /tmp/codex-dl; \
    codex --version

# Also makes a bare `codex` behave like `codex --yolo`.
RUN mkdir -p /root/.codex && cat > /root/.codex/config.toml <<'TOML'
approval_policy = "never"
sandbox_mode = "danger-full-access"

[projects."/workspace"]
trust_level = "trusted"
TOML

COPY container-rules.md /root/.codex/AGENTS.md

ENV CODEX_ACCESS_TOKEN="" \
    CODEX_AUTH_JSON="" \
    GH_TOKEN=""
WORKDIR /workspace

RUN cat > /usr/local/bin/codex-entrypoint <<'SH' && chmod +x /usr/local/bin/codex-entrypoint
#!/bin/sh
if [ -n "${CODEX_AUTH_JSON-}" ]; then
    printf '%s' "$CODEX_AUTH_JSON" > /root/.codex/auth.json
    chmod 600 /root/.codex/auth.json
fi
exec "$@"
SH
ENTRYPOINT ["/usr/local/bin/codex-entrypoint"]

CMD ["codex", "--yolo"]
