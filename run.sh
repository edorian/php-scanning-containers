#!/usr/bin/env bash
# Launch a scanning container on the current directory.
#
#   ./run.sh claude-php
#   ./run.sh codex-go
#   ./run.sh codex-ext bash      # a shell instead of the agent
#
# Mount something other than $PWD with WORKSPACE=/some/path ./run.sh …
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
        if [ -n "${CODEX_ACCESS_TOKEN-}" ]; then
            docker_args+=(-e "CODEX_ACCESS_TOKEN=${CODEX_ACCESS_TOKEN}")
        elif [ -n "${CODEX_AUTH_JSON-}" ]; then
            docker_args+=(-e "CODEX_AUTH_JSON=${CODEX_AUTH_JSON}")
        else
            echo 'Neither CODEX_ACCESS_TOKEN nor CODEX_AUTH_JSON is set. For a personal account: codex login, then export CODEX_AUTH_JSON="$(cat ~/.codex/auth.json)"' >&2
            exit 1
        fi
        ;;
esac

if [ -n "${GH_TOKEN-}" ]; then
    docker_args+=(-e "GH_TOKEN=${GH_TOKEN}")
fi

exec docker run "${docker_args[@]}" "${image}" "$@"
