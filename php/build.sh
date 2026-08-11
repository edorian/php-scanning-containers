#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# CLAUDE_INSTALL_BUST changes once per day so the agent install layers
# refresh daily. To force a refresh mid-day, pass CLAUDE_INSTALL_BUST=<anything new>.
BUST=${CLAUDE_INSTALL_BUST:-$(date +%Y-%m-%d)}

docker build --target claude \
    --build-arg CLAUDE_INSTALL_BUST="$BUST" -t claude-php .
docker build --target codex \
    --build-arg CODEX_INSTALL_BUST="$BUST" \
    --build-arg CODEX_VERSION="${CODEX_VERSION:-}" -t codex-php .

IMAGE=""
check() {
    printf "\n"'==> [%s] %s\n' "$IMAGE" "$1"; shift
    docker run --rm --entrypoint "" "$IMAGE" "$@"
}

shared_checks() {
    check "login shell PATH" bash -lc 'command -v php'
    check "php"            php --version
    check "composer"       composer --version
    check "gh"             gh --version
    check "jq"             jq --version
    check "rg"             rg --version
    check "fd"             fd --version
    check "semgrep"        semgrep --version
    check "zizmor"         zizmor --version
    check "php-src"        test -d /opt/php-src
}

IMAGE=claude-php
shared_checks
check "claude"         claude --version
check "CLAUDE.md"      test -s /root/.claude/CLAUDE.md
check "settings.json"  jq -r '"  model: \(.model)\n  effort: \(.effortLevel)"' /root/.claude/settings.json

IMAGE=codex-php
shared_checks
check "codex"          codex --version
check "codex --yolo"   codex --yolo --version
check "AGENTS.md"      test -s /root/.codex/AGENTS.md
printf "\n"'==> [%s] CODEX_AUTH_JSON\n' "$IMAGE"
docker run --rm -e CODEX_AUTH_JSON='{"probe":true}' codex-php sh -c 'cat /root/.codex/auth.json'

echo "OK"
