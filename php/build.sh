#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ../build-lib.sh

HARNESS_BUST=${HARNESS_BUST:-$(date +%Y-%m-%d)}

echo "Building PHP images..."
docker build -f Dockerfile --target claude \
    --build-arg CLAUDE_INSTALL_BUST="$HARNESS_BUST" \
    --build-arg CLAUDE_MODEL="$CLAUDE_MODEL" \
    --build-arg CLAUDE_EFFORT="$CLAUDE_EFFORT" \
    --build-arg PHP_GIT_REF="${PHP_GIT_REF:-php-8.5.10}" -t claude-php ..
docker build -f Dockerfile --target codex \
    --build-arg CODEX_INSTALL_BUST="$HARNESS_BUST" \
    --build-arg CODEX_MODEL="$CODEX_MODEL" \
    --build-arg CODEX_EFFORT="$CODEX_EFFORT" \
    --build-arg CODEX_VERSION="${CODEX_VERSION:-}" \
    --build-arg PHP_GIT_REF="${PHP_GIT_REF:-php-8.5.10}" -t codex-php ..

shared_checks() {
    check_common_tools
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
check "settings.json"  jq -e --arg m "$CLAUDE_MODEL" --arg e "$CLAUDE_EFFORT" '.model == $m and .effortLevel == $e' /root/.claude/settings.json

IMAGE=codex-php
shared_checks
check "codex"          codex --version
check "codex --yolo"   codex --yolo --version
check "AGENTS.md"      test -s /root/.codex/AGENTS.md
check "config.toml"    grep -Fqx "model = \"$CODEX_MODEL\"" /root/.codex/config.toml
check "reasoning"      grep -Fqx "model_reasoning_effort = \"$CODEX_EFFORT\"" /root/.codex/config.toml
check "code-mode host" test -x /opt/codex/bin/codex-code-mode-host
check "daemon"         codex app-server daemon start
check_codex_auth
echo "Built and checked claude-php and codex-php."
