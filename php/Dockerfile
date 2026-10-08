# syntax=docker/dockerfile:1.7

FROM debian:trixie-slim AS zizmor
ARG ZIZMOR_VERSION=1.30.1

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && arch="$(dpkg --print-architecture)" \
 && case "$arch" in \
        amd64) target=x86_64-unknown-linux-gnu ;; \
        arm64) target=aarch64-unknown-linux-gnu ;; \
        *) echo "zizmor: unsupported arch $arch"; exit 1 ;; \
    esac \
 && mkdir -p /tmp/zizmor-dl \
 && curl -fsSL "https://github.com/zizmorcore/zizmor/releases/download/v${ZIZMOR_VERSION}/zizmor-${target}.tar.gz" \
    | tar xz -C /tmp/zizmor-dl \
 && install -m 0755 "$(find /tmp/zizmor-dl -type f -name zizmor)" /usr/local/bin/zizmor \
 && rm -rf /var/lib/apt/lists/* /tmp/zizmor-dl

FROM debian:trixie-slim AS base

ARG PHP_GIT_REF=php-8.5.10
ARG PHP_GIT_URL=https://github.com/php/php-src.git

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/php/bin:/usr/local/php/sbin:/root/.local/bin:/root/.composer/vendor/bin:$PATH \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COLORTERM=truecolor

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential autoconf bison re2c pkg-config make \
        ca-certificates curl git xz-utils unzip less \
        jq ripgrep fd-find python3 python3-pip \
        libxml2-dev libssl-dev libsqlite3-dev libcurl4-openssl-dev \
        libonig-dev libzip-dev libbz2-dev libreadline-dev \
        libpng-dev libjpeg-dev libfreetype6-dev libwebp-dev libxpm-dev \
        libgmp-dev libicu-dev libldap2-dev libpq-dev libsasl2-dev \
        default-libmysqlclient-dev \
        libsodium-dev libxslt1-dev libtidy-dev libffi-dev libargon2-dev \
        zlib1g-dev \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s "$(command -v fdfind)" /usr/local/bin/fd \
 && pip3 install --break-system-packages --no-cache-dir semgrep

WORKDIR /opt
RUN git clone --depth 1 --branch "${PHP_GIT_REF}" "${PHP_GIT_URL}" php-src
WORKDIR /opt/php-src
RUN ./buildconf --force \
 && ./configure \
        --prefix=/usr/local/php \
        --with-config-file-path=/usr/local/php/etc \
        --with-config-file-scan-dir=/usr/local/php/etc/conf.d \
        --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data \
        --enable-cli \
        --enable-bcmath --enable-calendar --enable-exif --enable-ftp \
        --enable-gd --with-jpeg --with-webp --with-xpm --with-freetype \
        --enable-intl --enable-mbstring --enable-mysqlnd --enable-opcache \
        --enable-pcntl --enable-shmop --enable-soap --enable-sockets \
        --enable-sysvmsg --enable-sysvsem --enable-sysvshm \
        --with-bz2 --with-curl --with-ffi --with-gmp \
        --with-ldap --with-ldap-sasl --with-mhash --with-mysqli \
        --with-openssl --with-password-argon2 \
        --with-pdo-mysql --with-pdo-pgsql --with-pdo-sqlite --with-pgsql \
        --with-readline --with-sodium --with-sqlite3 \
        --with-tidy --with-xsl --with-zip --with-zlib --with-pear \
 && make -j"$(nproc)" \
 && make install \
 && mkdir -p /usr/local/php/etc/conf.d \
 && cp php.ini-development /usr/local/php/etc/php.ini

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
COPY --from=zizmor /usr/local/bin/zizmor /usr/local/bin/zizmor

# Preserve PATH in login shells.
RUN printf 'export PATH=%s\n' "$PATH" > /etc/profile.d/10-path.sh

FROM base AS tooling
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
COPY php/container-rules.md /root/.claude/CLAUDE.md

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
COPY php/container-rules.md /root/.codex/AGENTS.md

ENV CODEX_ACCESS_TOKEN="" \
    CODEX_AUTH_JSON="" \
    GH_TOKEN=""
WORKDIR /workspace

COPY --chmod=755 harness/codex-entrypoint /usr/local/bin/codex-entrypoint
ENTRYPOINT ["/usr/local/bin/codex-entrypoint"]

CMD ["codex", "--yolo"]
