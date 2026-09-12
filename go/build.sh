#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ../build-lib.sh

BUST=${CLAUDE_INSTALL_BUST:-$(date +%Y-%m-%d)}

echo "Building Go images..."
docker build --quiet --target claude \
    --build-arg CLAUDE_INSTALL_BUST="$BUST" \
    --build-arg GO_VERSION="${GO_VERSION:-}" -t claude-go . > /dev/null
docker build --quiet --target codex \
    --build-arg CODEX_INSTALL_BUST="$BUST" \
    --build-arg CODEX_VERSION="${CODEX_VERSION:-}" \
    --build-arg GO_VERSION="${GO_VERSION:-}" -t codex-go . > /dev/null

shared_checks() {
    check "login shell PATH" bash -lc 'command -v go'
    check "go"             go version
    check "gofmt"          sh -c 'command -v gofmt'
    check "cgo"            sh -c 'go env CGO_ENABLED | grep -qx 1'
    check "stdlib source"  test -d /usr/local/go/src/runtime

    check "race e2e"       sh -c '
        mkdir -p /tmp/race && cd /tmp/race
        cat > go.mod <<EOF
module race

go 1.21
EOF
        cat > main.go <<EOF
package main

import "sync"

func main() {
	n := 0
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); n++ }()
	}
	wg.Wait()
	_ = n
}
EOF
        out=$(go run -race . 2>&1 || true)
        echo "$out" | grep -q "DATA RACE" || { echo "race detector did not fire:"; echo "$out"; exit 1; }
    '

    check "staticcheck"    staticcheck --version
    check "golangci-lint"  golangci-lint --version
    check "govulncheck"    govulncheck -version
    check "gosec"          gosec --version
    check "goimports"      sh -c 'command -v goimports'
    check "gofumpt"        gofumpt --version
    check "gopls"          gopls version
    check "dlv"            dlv version
    check "gotestsum"      gotestsum --version
    check "gcc"            gcc --version
    check "clang"          clang --version
    check "gh"             gh --version
    check "jq"             jq --version
    check "rg"             rg --version
    check "fd"             fd --version
    check "semgrep"        semgrep --version
}

IMAGE=claude-go
shared_checks
check "claude"         claude --version
check "CLAUDE.md"      test -s /root/.claude/CLAUDE.md
check "settings.json"  jq -r '"  model: \(.model)\n  effort: \(.effortLevel)"' /root/.claude/settings.json

IMAGE=codex-go
shared_checks
check "codex"          codex --version
check "codex --yolo"   codex --yolo --version
check "AGENTS.md"      test -s /root/.codex/AGENTS.md
check "code-mode host" test -x /usr/local/bin/codex-code-mode-host
check_codex_auth
echo "Built and checked claude-go and codex-go."
