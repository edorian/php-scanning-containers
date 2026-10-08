#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=../build-lib.sh
source ../build-lib.sh

HARNESS_BUST=${HARNESS_BUST:-$(date +%Y-%m-%d)}

build_profile php --build-arg "PHP_GIT_REF=${PHP_GIT_REF:-php-8.5.10}"

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

use_image "$TOOLING_IMAGE"
shared_checks

use_image claude-php
check_claude_agent "PHP rules"
use_image codex-php
check_codex_agent "PHP rules"
echo "Built and checked claude-php and codex-php."
