#!/usr/bin/env bash

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Committed default models and effort; an untracked models.local.env overrides them.
# shellcheck source=models.env
source "$REPO_ROOT/models.env"
if [ -f "$REPO_ROOT/models.local.env" ]; then
    # shellcheck source=/dev/null
    source "$REPO_ROOT/models.local.env"
fi
echo "Models: claude=$CLAUDE_MODEL ($CLAUDE_EFFORT) codex=$CODEX_MODEL ($CODEX_EFFORT)"

build_profile() {
    local profile=$1 base_image
    shift

    base_image="agent-scanner-base:${profile}"
    TOOLING_IMAGE="agent-scanner-tooling:${profile}"

    echo "Building ${profile} toolchain..."
    docker build --provenance=false \
        -f "$REPO_ROOT/$profile/Dockerfile" --target base \
        -t "$base_image" "$@" "$REPO_ROOT"

    echo "Adding shared tools..."
    docker build --provenance=false \
        -f "$REPO_ROOT/harness/Dockerfile" --target tooling \
        --build-arg "BASE_IMAGE=$base_image" \
        -t "$TOOLING_IMAGE" "$REPO_ROOT"

    echo "Adding Claude Code..."
    docker build -f "$REPO_ROOT/harness/Dockerfile" --target claude \
        --build-arg "BASE_IMAGE=$base_image" \
        --build-arg "PROFILE=$profile" \
        --build-arg "CLAUDE_INSTALL_BUST=$HARNESS_BUST" \
        --build-arg "CLAUDE_MODEL=$CLAUDE_MODEL" \
        --build-arg "CLAUDE_EFFORT=$CLAUDE_EFFORT" \
        -t "claude-${profile}" "$REPO_ROOT"

    echo "Adding Codex..."
    docker build -f "$REPO_ROOT/harness/Dockerfile" --target codex \
        --build-arg "BASE_IMAGE=$base_image" \
        --build-arg "PROFILE=$profile" \
        --build-arg "CODEX_INSTALL_BUST=$HARNESS_BUST" \
        --build-arg "CODEX_MODEL=$CODEX_MODEL" \
        --build-arg "CODEX_EFFORT=$CODEX_EFFORT" \
        --build-arg "CODEX_VERSION=${CODEX_VERSION:-}" \
        -t "codex-${profile}" "$REPO_ROOT"
}

check() {
    local label=$1 output
    shift
    if ! output=$(docker run --rm --entrypoint "" "$IMAGE" "$@" 2>&1); then
        printf 'FAILED [%s] %s\n%s\n' "$IMAGE" "$label" "$output" >&2
        exit 1
    fi
}

use_image() {
    IMAGE=$1
}

check_common_tools() {
    check "process tools" sh -c 'command -v ps && command -v pgrep && command -v pkill && command -v pstree && command -v fuser'
    check "network tools" sh -c 'command -v ip && command -v ss && command -v ping && command -v nc && command -v dig && command -v socat'
    check "debug utilities" sh -c 'command -v file && command -v tree && command -v time && command -v ssh && command -v rsync && command -v sqlite3 && command -v shellcheck'
    check "node" node --version
}

# The positional parameters expand in the container shell.
# shellcheck disable=SC2016
check_rules() {
    local path=$1 section=$2
    check "agent rules" sh -c '
        test -s "$1"
        grep -Fqx "## $2" "$1"
    ' sh "$path" "$section"
}

check_claude_agent() {
    local section=$1 settings_filter
    settings_filter=".model == \$m and .effortLevel == \$e"
    check "claude" claude --version
    check_rules /root/.claude/CLAUDE.md "$section"
    check "settings.json" jq -e \
        --arg m "$CLAUDE_MODEL" --arg e "$CLAUDE_EFFORT" \
        "$settings_filter" /root/.claude/settings.json
}

check_codex_agent() {
    local section=$1
    check "codex" codex --version
    check "codex --yolo" codex --yolo --version
    check_rules /root/.codex/AGENTS.md "$section"
    check "config.toml" grep -Fqx "model = \"$CODEX_MODEL\"" /root/.codex/config.toml
    check "reasoning" grep -Fqx "model_reasoning_effort = \"$CODEX_EFFORT\"" /root/.codex/config.toml
    check "code-mode host" test -x /opt/codex/bin/codex-code-mode-host
    check "daemon" codex app-server daemon start
    check_codex_auth
}

check_codex_auth() {
    local out probe
    if ! out=$(docker run --rm "$IMAGE" sh -c 'test ! -e /root/.codex/auth.json' 2>&1); then
        printf 'FAILED [%s] unauthenticated startup\n%s\n' "$IMAGE" "$out" >&2
        exit 1
    fi

    probe='{"tokens":{"access_token":"probe","refresh_token":""}}'
    if ! out=$(docker run --rm -e "CODEX_AUTH_JSON=$probe" "$IMAGE" \
        sh -c 'test "$(jq -r .tokens.access_token /root/.codex/auth.json)" = probe && test -z "${CODEX_AUTH_JSON-}"' 2>&1); then
        printf 'FAILED [%s] credential injection\n%s\n' "$IMAGE" "$out" >&2
        exit 1
    fi
}
