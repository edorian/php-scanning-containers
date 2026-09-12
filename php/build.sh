#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ../build-lib.sh

BUST=${CLAUDE_INSTALL_BUST:-$(date +%Y-%m-%d)}

echo "Building PHP images..."
docker build --quiet --target claude \
    --build-arg CLAUDE_INSTALL_BUST="$BUST" \
    --build-arg PHP_GIT_REF="${PHP_GIT_REF:-php-8.5.9}" -t claude-php . > /dev/null
docker build --quiet --target codex \
    --build-arg CODEX_INSTALL_BUST="$BUST" \
    --build-arg CODEX_VERSION="${CODEX_VERSION:-}" \
    --build-arg PHP_GIT_REF="${PHP_GIT_REF:-php-8.5.9}" -t codex-php . > /dev/null

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
check "code-mode host" test -x /usr/local/bin/codex-code-mode-host
check_codex_auth
echo "Built and checked claude-php and codex-php."
