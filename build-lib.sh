check() {
    local label=$1 output
    shift
    if ! output=$(docker run --rm --entrypoint "" "$IMAGE" "$@" 2>&1); then
        printf 'FAILED [%s] %s\n%s\n' "$IMAGE" "$label" "$output" >&2
        exit 1
    fi
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
