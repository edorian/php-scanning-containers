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

ARG PHP_GIT_REF=master
ARG PHP_GIT_URL=https://github.com/php/php-src.git

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/php/bin:/usr/local/php/sbin:/root/.local/bin:/root/.composer/vendor/bin:$PATH \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COLORTERM=truecolor \
    USE_ZEND_ALLOC=0 \
    ASAN_OPTIONS="symbolize=1:strict_string_checks=1:detect_stack_use_after_return=1:detect_leaks=0:print_summary=1" \
    UBSAN_OPTIONS="print_stacktrace=1:print_summary=1"

COPY harness/base-packages.txt harness/php-build-packages.txt ext/build-packages.txt /tmp/packages/
RUN apt-get update \
 && cat /tmp/packages/*.txt | xargs -r apt-get install -y --no-install-recommends \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && ln -s "$(command -v fdfind)" /usr/local/bin/fd \
 && pip3 install --break-system-packages --no-cache-dir semgrep \
 && rm -rf /var/lib/apt/lists/* /tmp/packages

# `php` is instrumented; `php-prod` is release NTS.
COPY harness/php-configure-options.txt /opt/php-configure-options.txt
WORKDIR /opt
ARG PHP_SRC_BUST=0
RUN : "${PHP_SRC_BUST}" \
 && git clone --depth 1 --branch "${PHP_GIT_REF}" "${PHP_GIT_URL}" php-src
WORKDIR /opt/php-src
RUN ./buildconf --force

# Build production in a copy so /opt/php-src retains the instrumented tree.
RUN cp -a /opt/php-src /tmp/php-src-prod \
 && cd /tmp/php-src-prod \
 && xargs ./configure \
        --prefix=/usr/local/php-prod \
        --with-config-file-path=/usr/local/php-prod/etc \
        --with-config-file-scan-dir=/usr/local/php-prod/etc/conf.d \
        < /opt/php-configure-options.txt \
 && make -j"$(nproc)" \
 && make install \
 && mkdir -p /usr/local/php-prod/etc/conf.d \
 && cp php.ini-production /usr/local/php-prod/etc/php.ini \
 && cd / && rm -rf /tmp/php-src-prod

RUN xargs ./configure \
        --prefix=/usr/local/php \
        --with-config-file-path=/usr/local/php/etc \
        --with-config-file-scan-dir=/usr/local/php/etc/conf.d \
        --enable-debug \
        --enable-zts \
        --enable-address-sanitizer \
        --enable-undefined-sanitizer \
        < /opt/php-configure-options.txt \
 && make -j"$(nproc)" \
 && make install \
 && mkdir -p /usr/local/php/etc/conf.d \
 && cp php.ini-development /usr/local/php/etc/php.ini \
 && printf 'zend.assertions=1\n' >> /usr/local/php/etc/php.ini

# Run commands against the release build without sanitizer settings.
RUN cat > /usr/local/bin/prod-env <<'SH' && chmod +x /usr/local/bin/prod-env
#!/bin/sh
unset CFLAGS CXXFLAGS LDFLAGS ASAN_OPTIONS UBSAN_OPTIONS USE_ZEND_ALLOC
PATH=/usr/local/php-prod/bin:/usr/local/php-prod/sbin:$PATH
export PATH
exec "$@"
SH

RUN cat > /usr/local/bin/php-prod <<'SH' && chmod +x /usr/local/bin/php-prod
#!/bin/sh
exec /usr/local/bin/prod-env /usr/local/php-prod/bin/php "$@"
SH

ENV CFLAGS="-fsanitize=address -DZEND_TRACK_ARENA_ALLOC -fsanitize=undefined -fno-sanitize-recover=undefined -fno-sanitize=object-size -fno-omit-frame-pointer -g -O1" \
    CXXFLAGS="-fsanitize=address -DZEND_TRACK_ARENA_ALLOC -fsanitize=undefined -fno-sanitize-recover=undefined -fno-sanitize=object-size -fno-omit-frame-pointer -g -O1" \
    LDFLAGS="-fsanitize=address -fsanitize=undefined"

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
COPY --from=zizmor /usr/local/bin/zizmor /usr/local/bin/zizmor

# Preserve PATH in login shells.
RUN printf 'export PATH=%s\n' "$PATH" > /etc/profile.d/10-path.sh
