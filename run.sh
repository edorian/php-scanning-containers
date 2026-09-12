#!/usr/bin/env bash
set -euo pipefail

IMAGES="claude-php claude-ext claude-go codex-php codex-ext codex-go"

image=${1:-}
case " ${IMAGES} " in
    *" ${image} "*) shift ;;
    *)
        echo "usage: $0 <image> [command…]" >&2
        echo "images: ${IMAGES}" >&2
        exit 2
        ;;
esac

WORKSPACE=${WORKSPACE:-$PWD}
docker_args=(--rm -it -v "${WORKSPACE}:/workspace")

case "${image}" in
    claude-*)
        if [ -z "${CLAUDE_CODE_OAUTH_TOKEN-}" ]; then
            echo "CLAUDE_CODE_OAUTH_TOKEN is not set. Get one with: claude setup-token" >&2
            exit 1
        fi
        docker_args+=(-e "CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN}")
        ;;
    codex-*)
        auth_file=${CODEX_AUTH_FILE:-$HOME/.codex/auth.json}
        if [ -n "${CODEX_ACCESS_TOKEN-}" ]; then
            docker_args+=(-e "CODEX_ACCESS_TOKEN=${CODEX_ACCESS_TOKEN}")
        elif [ -f "${auth_file}" ]; then
            command -v jq > /dev/null || {
                echo "jq is required to prepare Codex credentials." >&2
                exit 1
            }
            auth_json=$(jq -ce '
                if (.tokens.access_token? | type) == "string" then
                    .tokens.refresh_token = ""
                else
                    error("auth file has no ChatGPT access token")
                end
            ' "${auth_file}") || {
                echo "Could not read ChatGPT credentials from ${auth_file}. Run codex login on the host." >&2
                exit 1
            }
            docker_args+=(-e "CODEX_AUTH_JSON=${auth_json}")
        else
            echo "${auth_file} does not exist. Run codex login on the host." >&2
            exit 1
        fi
        ;;
esac

if [ -n "${GH_TOKEN-}" ]; then
    docker_args+=(-e "GH_TOKEN=${GH_TOKEN}")
fi

printf 'Starting %s with %s mounted at /workspace\n' "$image" "$WORKSPACE"
exec docker run "${docker_args[@]}" "${image}" "$@"
