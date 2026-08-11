# syntax=docker/dockerfile:1.7

# zizmor — separate builder stage. Upstream ghcr.io/zizmorcore/zizmor is
# Alpine/musl, won't run on our debian/glibc base, so we pull the matching
# glibc release tarball from GitHub. Bump ZIZMOR_VERSION to update.
FROM debian:bookworm-slim AS zizmor
ARG ZIZMOR_VERSION=1.29.0

# Older releases nested the binary in zizmor-<target>/; find it either way.
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

FROM debian:bookworm-slim AS base

ARG PHP_GIT_REF=master
ARG PHP_GIT_URL=https://github.com/php/php-src.git

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/php/bin:/usr/local/php/sbin:/root/.local/bin:/root/.composer/vendor/bin:$PATH \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COLORTERM=truecolor \
    USE_ZEND_ALLOC=0 \
    ASAN_OPTIONS="symbolize=1:strict_string_checks=1:detect_stack_use_after_return=1:detect_leaks=0:print_summary=1" \
    UBSAN_OPTIONS="print_stacktrace=1:print_summary=1"

# Toolchain
# Both gcc (build-essential) and clang/llvm are installed so extension /
# harness code can be built with either. PHP itself is built with gcc
# below; clang-built .so files that get dlopen'd into PHP will clash with
# PHP's gcc libasan runtime — use clang for standalone fuzz harnesses /
# test programs, gcc for anything loaded into the PHP binary.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential autoconf bison re2c pkg-config make \
        clang lld llvm clang-tools clang-format clang-tidy \
        libclang-rt-14-dev libc++-dev libc++abi-dev \
        ca-certificates curl git xz-utils unzip less \
        jq ripgrep fd-find python3 python3-pip \
        gdb valgrind strace lsof \
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

# PHP - debug build with AddressSanitizer + UndefinedBehaviorSanitizer.
#
# - --enable-debug         : ZEND_DEBUG, assertions, no -O2 stripping
# - --enable-address-sanitizer / --enable-undefined-sanitizer: PHP's own
#   configure switches; they append -fsanitize=address -DZEND_TRACK_ARENA_ALLOC
#   -fsanitize=undefined -fno-sanitize-recover=undefined -fno-sanitize=object-size
#   into the PHP build. We re-export the same set as env CFLAGS/LDFLAGS *after*
#   `make install` so phpize-built extensions inherit the matching flags.
WORKDIR /opt
RUN git clone --depth 1 --branch "${PHP_GIT_REF}" "${PHP_GIT_URL}" php-src
WORKDIR /opt/php-src
RUN ./buildconf --force \
 && ./configure \
        --prefix=/usr/local/php \
        --with-config-file-path=/usr/local/php/etc \
        --with-config-file-scan-dir=/usr/local/php/etc/conf.d \
        --enable-debug \
        --enable-zts \
        --enable-address-sanitizer \
        --enable-undefined-sanitizer \
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
 && cp php.ini-development /usr/local/php/etc/php.ini \
 && printf 'zend.assertions=1\n' >> /usr/local/php/etc/php.ini

# Sanitizer flags for downstream extension builds (phpize && ./configure picks
# them up via env). Match the set PHP itself was built with.
ENV CFLAGS="-fsanitize=address -DZEND_TRACK_ARENA_ALLOC -fsanitize=undefined -fno-sanitize-recover=undefined -fno-sanitize=object-size -fno-omit-frame-pointer -g -O1" \
    CXXFLAGS="-fsanitize=address -DZEND_TRACK_ARENA_ALLOC -fsanitize=undefined -fno-sanitize-recover=undefined -fno-sanitize=object-size -fno-omit-frame-pointer -g -O1" \
    LDFLAGS="-fsanitize=address -fsanitize=undefined"

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
COPY --from=zizmor /usr/local/bin/zizmor /usr/local/bin/zizmor

# A login shell (`bash -lc`) re-sets PATH from /etc/profile and drops
# everything ENV added. Codex runs commands that way; re-export it.
RUN printf 'export PATH=%s\n' "$PATH" > /etc/profile.d/10-path.sh

FROM base AS claude

# build.sh sets CLAUDE_INSTALL_BUST to today's date by default, so this
# layer (and everything below it) refreshes once per day. Pass a different
# value (or use --no-cache) to force a mid-day refresh.
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
  "tui": "default",
  "skipDangerousModePermissionPrompt": true,
  "awaySummaryEnabled": false,
  "spinnerTipsEnabled": false,
  "spinnerVerbs": {
    "mode": "replace",
    "verbs": ["Thinking"]
  }
}
JSON

COPY container-rules.md /root/.claude/CLAUDE.md

# Tokens injected at run time (-e). gh reads GH_TOKEN directly, no `gh auth
# login`; empty default = logged out. IS_SANDBOX=1 lets
# --dangerously-skip-permissions run as root.
ENV CLAUDE_CODE_OAUTH_TOKEN="" \
    GH_TOKEN="" \
    IS_SANDBOX=1
WORKDIR /workspace

CMD ["claude", "--dangerously-skip-permissions", "--effort", "xhigh"]

FROM base AS codex

# Static musl binary, so the npm package (and Node with it) is not needed.
# Empty CODEX_VERSION = latest release at build time.
ARG CODEX_INSTALL_BUST=0
ARG CODEX_VERSION=
RUN set -eux; \
    echo "codex install bust=${CODEX_INSTALL_BUST}"; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) target=x86_64-unknown-linux-musl ;; \
        arm64) target=aarch64-unknown-linux-musl ;; \
        *) echo "codex: unsupported arch $arch" >&2; exit 1 ;; \
    esac; \
    tag="${CODEX_VERSION:-$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest | jq -r .tag_name)}"; \
    mkdir -p /tmp/codex-dl; \
    curl -fsSL "https://github.com/openai/codex/releases/download/${tag}/codex-${target}.tar.gz" \
        | tar xz -C /tmp/codex-dl; \
    install -m 0755 "$(find /tmp/codex-dl -type f -name 'codex*' | head -n1)" /usr/local/bin/codex; \
    rm -rf /tmp/codex-dl; \
    codex --version

# Also makes a bare `codex` behave like `codex --yolo`.
RUN mkdir -p /root/.codex && cat > /root/.codex/config.toml <<'TOML'
approval_policy = "never"
sandbox_mode = "danger-full-access"

[projects."/workspace"]
trust_level = "trusted"
TOML

COPY container-rules.md /root/.codex/AGENTS.md

ENV CODEX_ACCESS_TOKEN="" \
    CODEX_AUTH_JSON="" \
    GH_TOKEN=""
WORKDIR /workspace

RUN cat > /usr/local/bin/codex-entrypoint <<'SH' && chmod +x /usr/local/bin/codex-entrypoint
#!/bin/sh
if [ -n "${CODEX_AUTH_JSON-}" ]; then
    printf '%s' "$CODEX_AUTH_JSON" > /root/.codex/auth.json
    chmod 600 /root/.codex/auth.json
fi
exec "$@"
SH
ENTRYPOINT ["/usr/local/bin/codex-entrypoint"]

CMD ["codex", "--yolo"]
