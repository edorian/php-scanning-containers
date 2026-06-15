# syntax=docker/dockerfile:1.7

# zizmor — separate builder stage. Upstream ghcr.io/zizmorcore/zizmor is
# Alpine/musl, won't run on our debian/glibc base, so we pull the matching
# glibc release tarball from GitHub. Bump ZIZMOR_VERSION to update.
FROM debian:bookworm-slim AS zizmor
ARG ZIZMOR_VERSION=1.25.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && arch="$(dpkg --print-architecture)" \
# && case "$arch" in \
#       amd64) target=x86_64-unknown-linux-gnu ;; \
#        arm64) target=aarch64-unknown-linux-gnu ;; \
#        *) echo "zizmor: unsupported arch $arch"; exit 1 ;; \
#    esac \
# && curl -fsSL "https://github.com/zizmorcore/zizmor/releases/download/v${ZIZMOR_VERSION}/zizmor-${target}.tar.gz" \
#    | tar xz -C /tmp \
# && mv "/tmp/zizmor-${target}/zizmor" /usr/local/bin/zizmor
 && rm -rf /var/lib/apt/lists/*

FROM debian:bookworm-slim

ARG PHP_GIT_REF=php-8.5.7
ARG PHP_GIT_URL=https://github.com/php/php-src.git

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/php/bin:/usr/local/php/sbin:/root/.local/bin:/root/.composer/vendor/bin:$PATH \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COLORTERM=truecolor

# Toolchain - Kept so the container can rebuild
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

# php
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
#COPY --from=zizmor /usr/local/bin/zizmor /usr/local/bin/zizmor

# Claude Code. build.sh sets CLAUDE_INSTALL_BUST to today's date by default,
# so this layer (and everything below it) refreshes once per day. Pass a
# different value (or use --no-cache) to force a mid-day refresh.
ARG CLAUDE_INSTALL_BUST=0
RUN echo "claude install bust=${CLAUDE_INSTALL_BUST}" \
 && curl -fsSL https://claude.ai/install.sh | bash

RUN printf '%s' '{"hasCompletedOnboarding":true,"hasTrustDialogAccepted":true,"hasTrustDialogHooksAccepted":true,"projects":{"/workspace":{"hasTrustDialogAccepted":true,"hasTrustDialogHooksAccepted":true}}}' \
    > /root/.claude.json

RUN mkdir -p /root/.claude && cat > /root/.claude/settings.json <<'JSON'
{
  "model": "claude-opus-4-8",
  "theme": "dark",
  "effortLevel": "xhigh",
  "skipDangerousModePermissionPrompt": true,
  "awaySummaryEnabled": false,
  "spinnerVerbs": {
    "mode": "replace",
    "verbs": ["Thinking"]
  }
}
JSON

# Global CLAUDE.md - ground rules for the scanning container
RUN cat > /root/.claude/CLAUDE.md <<'MD'
# claude-php scanning container

PHP analysis sandbox. Running as root with `--dangerously-skip-permissions`,
so run shell commands, write files, and install packages freely.

## Layout

- `/workspace` — target codebase (host mount). Start here.
- `/usr/local/php` — PHP built from `php-src` master; `php`, `phpize`,
  `php-config`, `php-fpm` on PATH.
- `/opt/php-src` — PHP source tree, build deps installed (rebuildable).
- `composer`, `gh`, `claude`, `semgrep`, `zizmor`, `jq`, `rg`, `fd` — on PATH.
  `gh` auths from `$GH_TOKEN`.

## Rules

1. Back every claim with a command you ran in the container. Prefer running
   things (`php -l`, `composer validate`, `vendor/bin/phpunit`, `gh …`) over
   static reasoning.
2. Bootstrap before analyzing: if `composer.json` exists but `vendor/` is
   missing (or the lock is stale), run `composer install`/`update`. Same
   for any obvious build step the project needs.
3. Install missing tools (apt, `composer global require`, pecl) without
   asking; mention in your reply what you added.
4. Before handing back a patch, discover the project's QA tools (composer
   scripts, `phpcs.xml`, `phpstan.neon`, `psalm.xml`, `rector.php`,
   `.php-cs-fixer.php`, `phpunit.xml`, CI configs) and run the ones that
   apply against the change. Fix what they flag, or explain why not.
   Report results.
MD

# Tokens injected at run time (-e). gh reads GH_TOKEN directly, no `gh auth
# login`; empty default = logged out. IS_SANDBOX=1 lets
# --dangerously-skip-permissions run as root.
ENV CLAUDE_CODE_OAUTH_TOKEN="" \
    GH_TOKEN="" \
    IS_SANDBOX=1
WORKDIR /workspace

CMD ["claude", "--dangerously-skip-permissions", "--effort", "xhigh"]
