#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# CLAUDE_INSTALL_BUST changes once per day so the claude install layer
# refreshes daily. To force a refresh mid-day, pass CLAUDE_INSTALL_BUST=<anything new>.
# GO_VERSION pins the toolchain (e.g. go1.25.0); empty = current stable.
docker build \
    --build-arg CLAUDE_INSTALL_BUST="${CLAUDE_INSTALL_BUST:-$(date +%Y-%m-%d)}" \
    --build-arg GO_VERSION="${GO_VERSION:-}" \
    -t claude-go .

check() {
    printf "\n"'==> %s\n' "$1"; shift
    docker run --rm --entrypoint "" claude-go "$@"
}

check "go"             go version
check "gofmt"          sh -c 'command -v gofmt'
check "cgo"            sh -c 'go env CGO_ENABLED | grep -qx 1'
check "stdlib source"  test -d /usr/local/go/src/runtime

# End-to-end: a program with a known data race must be caught by the race
# detector. Exercises cgo, the external linker, and the race runtime in one
# shot — all three break silently otherwise.
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
    echo "  race detector OK"
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
check "claude"         claude --version
check "jq"             jq --version
check "rg"             rg --version
check "fd"             fd --version
check "semgrep"        semgrep --version
check "CLAUDE.md"      test -s /root/.claude/CLAUDE.md
check "settings.json"  jq -r '"  model: \(.model)\n  effort: \(.effortLevel)"' /root/.claude/settings.json

echo "OK"
