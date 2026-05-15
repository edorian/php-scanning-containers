#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# CLAUDE_INSTALL_BUST changes once per day so the claude install layer
# refreshes daily. To force a refresh mid-day, pass CLAUDE_INSTALL_BUST=<anything new>.
docker build --build-arg CLAUDE_INSTALL_BUST="${CLAUDE_INSTALL_BUST:-$(date +%Y-%m-%d)}" -t claude-php .

check() {
    printf "\n"'==> %s\n' "$1"; shift
    docker run --rm --entrypoint "" claude-php "$@"
}

check "php"            php --version
check "composer"       composer --version
check "gh"             gh --version
check "claude"         claude --version
check "jq"             jq --version
check "rg"             rg --version
check "fd"             fd --version
check "semgrep"        semgrep --version
#check "zizmor"         zizmor --version
check "CLAUDE.md"      test -s /root/.claude/CLAUDE.md
check "settings.json"  jq -r '"  model: \(.model)\n  effort: \(.effortLevel)"' /root/.claude/settings.json
check "php-src"        test -d /opt/php-src

echo "OK"
