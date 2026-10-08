REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Committed default models and effort; an untracked models.local.env overrides them.
source "$REPO_ROOT/models.env"
if [ -f "$REPO_ROOT/models.local.env" ]; then
    source "$REPO_ROOT/models.local.env"
fi
echo "Models: claude=$CLAUDE_MODEL ($CLAUDE_EFFORT) codex=$CODEX_MODEL ($CODEX_EFFORT)"

check() {
    local label=$1 output
    shift
    if ! output=$(docker run --rm --entrypoint "" "$IMAGE" "$@" 2>&1); then
        printf 'FAILED [%s] %s\n%s\n' "$IMAGE" "$label" "$output" >&2
        exit 1
    fi
}

check_common_tools() {
    check "process tools" sh -c 'command -v ps && command -v pgrep && command -v pkill && command -v pstree && command -v fuser'
    check "network tools" sh -c 'command -v ip && command -v ss && command -v ping && command -v nc && command -v dig && command -v socat'
    check "debug utilities" sh -c 'command -v file && command -v tree && command -v time && command -v ssh && command -v rsync && command -v sqlite3 && command -v shellcheck'
    check "node" node --version
}

check_codex_auth() {
    local out probe
    out=$(docker run --rm "$IMAGE" 2>&1 || true)
    case "$out" in
        *"No Codex credentials"*) ;;
        *) printf 'FAILED [%s] credential guard\n%s\n' "$IMAGE" "$out" >&2; exit 1 ;;
    esac

    probe='{"tokens":{"access_token":"probe","refresh_token":""}}'
    if ! out=$(docker run --rm -e "CODEX_AUTH_JSON=$probe" "$IMAGE" \
        sh -c 'test "$(jq -r .tokens.access_token /root/.codex/auth.json)" = probe && test -z "${CODEX_AUTH_JSON-}"' 2>&1); then
        printf 'FAILED [%s] credential injection\n%s\n' "$IMAGE" "$out" >&2
        exit 1
    fi
}
