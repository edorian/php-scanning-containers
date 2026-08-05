# syntax=docker/dockerfile:1.7

FROM debian:bookworm-slim

# Empty GO_VERSION = resolve the current stable release at build time.
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

# Claude Code. build.sh sets CLAUDE_INSTALL_BUST to today's date by default,
# so this layer (and everything below it) refreshes once per day. Pass a
# different value (or use --no-cache) to force a mid-day refresh.
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

# Global CLAUDE.md - ground rules for the scanning container
RUN cat > /root/.claude/CLAUDE.md <<'MD'
# claude-go scanning container

Go analysis sandbox. Running as root with `--dangerously-skip-permissions`,
so run shell commands, write files, and install packages freely.

## Layout

- `/workspace` — target codebase (host mount). Start here.
- `/usr/local/go` — Go toolchain. `/usr/local/go/src` is the full stdlib
  source; read it when runtime/stdlib behaviour is in question.
- `/root/go` — GOPATH; installed tools land in `/root/go/bin` (on PATH).
- `go`, `gofmt`, `gofumpt`, `goimports`, `staticcheck`, `golangci-lint`,
  `govulncheck`, `gosec`, `gopls`, `dlv`, `gotestsum`, `gh`, `claude`,
  `semgrep`, `jq`, `rg`, `fd` — on PATH. `gh` auths from `$GH_TOKEN`.
- `GOTOOLCHAIN=auto`, so `go` downloads whatever toolchain the project's
  `go.mod` asks for. `go version` in `/workspace` is the truth, not the
  baked-in version.
- gcc and clang both present. `-race` works with the default gcc/cgo
  setup; `-msan` and `-asan` require `CC=clang`.

Output that should persist goes into /workspace

## Rules

1. Back every claim with a command you ran in the container. Prefer
   running things (`go build ./...`, `go vet ./...`, `go test ./...`,
   `gh …`) over static reasoning.
2. Bootstrap before analyzing: if `go.mod` exists, run `go mod download`
   (and `go mod tidy` only when you intend to change the module graph).
   For a vendored tree (`vendor/`), build with `-mod=vendor`.
3. Run tests with the race detector — `go test -race ./...` — whenever
   concurrency is anywhere near the change. A pass without `-race` says
   very little about a concurrent program.
4. If the package has fuzz targets (`func FuzzXxx(f *testing.F)`), run
   them: `go test -run '^$' -fuzz FuzzXxx -fuzztime 60s ./pkg`. Any new
   entry written to `testdata/fuzz/` is a reproducer — report it.
5. Install missing tools (apt, `go install`) without asking; mention in
   your reply what you added.
6. Before handing back a patch, discover the project's QA setup
   (`Makefile`, `Taskfile.yml`, `.golangci.yml`, `go.work`, CI configs)
   and run the checks that apply to the change. If the project pins its
   own linter config, use it rather than the image defaults. Fall back to
   `gofmt -l`, `go vet ./...`, `staticcheck ./...`, `govulncheck ./...`.
   Fix what they flag, or explain why not. Report results.
7. Build tags and GOOS/GOARCH hide code from a default build. When a file
   is behind a constraint, check it explicitly
   (`go build -tags integration ./...`, `GOOS=windows go vet ./...`)
   instead of assuming `./...` covered it.
MD

# Tokens injected at run time (-e). gh reads GH_TOKEN directly, no `gh auth
# login`; empty default = logged out. IS_SANDBOX=1 lets
# --dangerously-skip-permissions run as root.
ENV CLAUDE_CODE_OAUTH_TOKEN="" \
    GH_TOKEN="" \
    IS_SANDBOX=1
WORKDIR /workspace

CMD ["claude", "--dangerously-skip-permissions", "--effort", "xhigh"]
