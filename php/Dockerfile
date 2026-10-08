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

COPY harness/base-packages.txt harness/php-build-packages.txt /tmp/packages/
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

COPY harness/php-configure-options.txt /opt/php-configure-options.txt
WORKDIR /opt
RUN git clone --depth 1 --branch "${PHP_GIT_REF}" "${PHP_GIT_URL}" php-src
WORKDIR /opt/php-src
RUN ./buildconf --force \
 && xargs ./configure \
        --prefix=/usr/local/php \
        --with-config-file-path=/usr/local/php/etc \
        --with-config-file-scan-dir=/usr/local/php/etc/conf.d \
        < /opt/php-configure-options.txt \
 && make -j"$(nproc)" \
 && make install \
 && mkdir -p /usr/local/php/etc/conf.d \
 && cp php.ini-development /usr/local/php/etc/php.ini

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
COPY --from=zizmor /usr/local/bin/zizmor /usr/local/bin/zizmor

# Preserve PATH in login shells.
RUN printf 'export PATH=%s\n' "$PATH" > /etc/profile.d/10-path.sh
