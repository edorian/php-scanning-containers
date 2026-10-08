# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=debian:trixie-slim
FROM ${BASE_IMAGE} AS tooling

COPY harness/common-packages.txt /tmp/common-packages.txt
RUN apt-get update \
 && xargs -r apt-get install -y --no-install-recommends < /tmp/common-packages.txt \
 && rm -rf /var/lib/apt/lists/* /tmp/common-packages.txt

FROM tooling AS claude

ARG CLAUDE_INSTALL_BUST=0
RUN : "${CLAUDE_INSTALL_BUST}" \
 && curl -fsSL https://claude.ai/install.sh | bash

COPY harness/claude.json /root/.claude.json
COPY harness/claude-settings.json /root/.claude/settings.json
ARG CLAUDE_MODEL
ARG CLAUDE_EFFORT
RUN test -n "${CLAUDE_MODEL}" && test -n "${CLAUDE_EFFORT}" \
 && jq --arg m "${CLAUDE_MODEL}" --arg e "${CLAUDE_EFFORT}" '{model: $m, effortLevel: $e} + .' \
        /root/.claude/settings.json > /tmp/settings.json \
 && mv /tmp/settings.json /root/.claude/settings.json
ARG PROFILE
COPY harness/agent-rules.md /tmp/agent-rules.md
COPY ${PROFILE}/container-rules.md /tmp/container-rules.md
RUN { cat /tmp/agent-rules.md; echo; cat /tmp/container-rules.md; } > /root/.claude/CLAUDE.md \
 && rm /tmp/agent-rules.md /tmp/container-rules.md

# IS_SANDBOX=1 lets --dangerously-skip-permissions run as root.
ENV CLAUDE_EFFORT="${CLAUDE_EFFORT}" \
    CLAUDE_CODE_OAUTH_TOKEN="" \
    GH_TOKEN="" \
    IS_SANDBOX=1
WORKDIR /workspace

CMD ["sh", "-c", "exec claude --dangerously-skip-permissions --effort \"$CLAUDE_EFFORT\""]

FROM tooling AS codex

ARG CODEX_INSTALL_BUST=0
ARG CODEX_VERSION=
RUN set -eu; \
    : "${CODEX_INSTALL_BUST}"; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) target=x86_64-unknown-linux-musl ;; \
        arm64) target=aarch64-unknown-linux-musl ;; \
        *) echo "codex: unsupported arch $arch" >&2; exit 1 ;; \
    esac; \
    tag="${CODEX_VERSION:-$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest | jq -r .tag_name)}"; \
    case "$tag" in rust-v*) ;; v*) tag="rust-${tag}" ;; *) tag="rust-v${tag}" ;; esac; \
    curl -fsSL "https://github.com/openai/codex/releases/download/${tag}/codex-package-${target}.tar.gz" \
        | { mkdir -p /opt/codex && tar xz --no-same-owner -C /opt/codex; }; \
    ln -s /opt/codex/bin/codex /usr/local/bin/codex; \
    codex --version; \
    test -x /opt/codex/bin/codex-code-mode-host

COPY harness/codex-config.toml /root/.codex/config.toml
ARG CODEX_MODEL
ARG CODEX_EFFORT
RUN test -n "${CODEX_MODEL}" && test -n "${CODEX_EFFORT}" \
 && sed -i -e "1i model = \"${CODEX_MODEL}\"" \
        -e "1i model_reasoning_effort = \"${CODEX_EFFORT}\"" /root/.codex/config.toml
ARG PROFILE
COPY harness/agent-rules.md /tmp/agent-rules.md
COPY ${PROFILE}/container-rules.md /tmp/container-rules.md
RUN { cat /tmp/agent-rules.md; echo; cat /tmp/container-rules.md; } > /root/.codex/AGENTS.md \
 && rm /tmp/agent-rules.md /tmp/container-rules.md

ENV CODEX_ACCESS_TOKEN="" \
    CODEX_AUTH_JSON="" \
    GH_TOKEN=""
WORKDIR /workspace

COPY --chmod=755 harness/codex-entrypoint /usr/local/bin/codex-entrypoint
ENTRYPOINT ["/usr/local/bin/codex-entrypoint"]

CMD ["codex", "--yolo"]
