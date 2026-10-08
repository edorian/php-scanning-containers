#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=../build-lib.sh
source ../build-lib.sh

HARNESS_BUST=${HARNESS_BUST:-$(date +%Y-%m-%d)}

build_profile go --build-arg "GO_VERSION=${GO_VERSION:-}"

# Dollar expressions in the race test expand in the container shell.
# shellcheck disable=SC2016
shared_checks() {
    check_common_tools
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

use_image "$TOOLING_IMAGE"
shared_checks

use_image claude-go
check_claude_agent "Go rules"
use_image codex-go
check_codex_agent "Go rules"
echo "Built and checked claude-go and codex-go."
