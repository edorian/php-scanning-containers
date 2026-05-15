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
#        amd64) target=x86_64-unknown-linux-gnu ;; \
#        arm64) target=aarch64-unknown-linux-gnu ;; \
#        *) echo "zizmor: unsupported arch $arch"; exit 1 ;; \
#    esac \
# && curl -fsSL "https://github.com/zizmorcore/zizmor/releases/download/v${ZIZMOR_VERSION}/zizmor-${target}.tar.gz" \
#    | tar xz -C /tmp \
# && mv "/tmp/zizmor-${target}/zizmor" /usr/local/bin/zizmor
  && rm -rf /var/lib/apt/lists/*

FROM debian:bookworm-slim

ARG PHP_GIT_REF=master
ARG PHP_GIT_URL=https://github.com/php/php-src.git

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/php/bin:/usr/local/php/sbin:/root/.local/bin:/root/.composer/vendor/bin:$PATH \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COLORTERM=truecolor \
    USE_ZEND_ALLOC=0 \
    ASAN_OPTIONS="symbolize=1:strict_string_checks=1:detect_stack_use_after_return=1:detect_leaks=0:print_summary=1" \
    UBSAN_OPTIONS="print_stacktrace=1:print_summary=1"

# Toolchain - same as claude-php plus debugging tools.
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

# Global CLAUDE.md - ground rules for the extension scanning container
RUN cat > /root/.claude/CLAUDE.md <<'MD'
# claude-ext scanning container

PHP **extension** analysis sandbox. Running as root with
`--dangerously-skip-permissions`, so run shell commands, write files, and
install packages freely.

## What's special about this image

PHP is built **debug + AddressSanitizer + UndefinedBehaviorSanitizer**.
Use it to catch memory errors, leaks, UB, and refcount/object lifetime
bugs in C extensions. Pure-PHP analysis belongs in `claude-php`, not
here.

## Layout

- `/workspace` — target extension source (host mount). Start here.
- `/usr/local/php` — debug+ASan+UBSan PHP. `php`, `phpize`, `php-config`,
  `php-fpm` on PATH. `php -v` reports `(DEBUG)` plus sanitizer config.
- `/opt/php-src` — PHP source tree, build deps installed. Useful for
  reading Zend internals (`Zend/zend_*.h`) when triaging crashes.
- `composer`, `gh`, `claude`, `gdb`, `valgrind`, `strace`,
  `semgrep`, `zizmor`, `jq`, `rg`, `fd` — on PATH.
  (Valgrind cannot be combined with ASan — pick one per run.)
- Both **gcc** (default `cc`) and **clang** (with `lld`, `llvm`,
  `clang-tidy`, `clang-format`, `libclang-rt-14-dev`, `libc++`) on PATH.
  `llvm-symbolizer` is available so clang's ASan/UBSan reports
  symbolize cleanly.

## gcc vs clang

PHP itself is gcc-built, so its ASan runtime is `libasan.so` from gcc.
That has consequences for what you build with what:

- **PHP extensions** (anything you `extension=` into PHP): build with
  **gcc**. The pre-exported `CFLAGS`/`LDFLAGS` below work as-is. A
  clang-built `.so` dlopen'd into a gcc-asan PHP will abort with
  "AddressSanitizer: CHECK failed" or similar runtime-mismatch errors.
- **Standalone fuzz harnesses, test programs, libFuzzer targets**:
  build with **clang** (`CC=clang CXX=clang++`). The same
  `-fsanitize=address,undefined` flags work; clang additionally gives
  you `-fsanitize=fuzzer`, `-fsanitize=memory`, `-fsanitize=thread`,
  and better control-flow integrity options that gcc lacks.
- **Rebuilding PHP itself with clang**: supported — re-run the
  `/opt/php-src` configure line with `CC=clang CXX=clang++`. Then
  clang-built extensions will load. Don't mix afterwards.

## Build environment

Sanitizer flags are pre-exported so `phpize && ./configure && make`
picks them up automatically, matching what PHP itself was built with:

```
CFLAGS   = -fsanitize=address -DZEND_TRACK_ARENA_ALLOC \
           -fsanitize=undefined -fno-sanitize-recover=undefined \
           -fno-sanitize=object-size \
           -fno-omit-frame-pointer -g -O1
CXXFLAGS = (same)
LDFLAGS  = -fsanitize=address -fsanitize=undefined
```

`-fno-sanitize=object-size` is required — PHP's `zend_function` union
violates strict object-size, and php-src adds this flag itself.
`-DZEND_TRACK_ARENA_ALLOC` matters too: it changes how Zend's arena
allocator is compiled, and extensions need the same definition as the
core to keep allocator macros consistent.

Runtime knobs (also pre-set):

```
USE_ZEND_ALLOC=0      # disable Zend's arena so ASan sees every alloc
ASAN_OPTIONS=symbolize=1:strict_string_checks=1:\
             detect_stack_use_after_return=1:detect_leaks=0:print_summary=1
UBSAN_OPTIONS=print_stacktrace=1:print_summary=1
```

`detect_leaks=0` by default — PHP has known startup leaks that drown
signal. Flip to `=1` once you have a focused suspect.

`-fno-sanitize-recover=undefined` is baked in at compile time, so UB
**aborts** on first hit. That's what php-src CI uses.

## How to build & test an extension

```
cd /workspace
phpize
./configure --enable-<extname>
make -j"$(nproc)"

# Smoke test
php -d extension=$(pwd)/modules/<extname>.so --ri <extname>

# Run the extension's own .phpt suite under sanitizers
make test TESTS="-q --show-diff"
```

`phpize` and `php-config` point at the debug build, so the resulting
`.so` links against the matching Zend ABI.

## Rules

1. Back every claim with a command you ran in the container. `php -l`,
   `make test`, `gdb --args php …`, parsing ASan reports — prefer
   running things over static reasoning.
2. Build the extension before analyzing. If `config.m4` exists but no
   `Makefile`, run `phpize && ./configure && make`.
3. Run the project's `.phpt` tests if any exist. A clean `make test`
   summary doesn't mean a clean sanitizer run — grep the test logs for
   `AddressSanitizer:` / `UndefinedBehaviorSanitizer:` / `runtime error:`.
4. When triaging a crash:
   - Re-run under `gdb --args php -d extension=… script.php`, `bt full`.
   - Cross-reference with `/opt/php-src` headers for `ZVAL_*`,
     `Z_ADDREF_P`, `OBJ_RELEASE`, arena vs. emalloc usage.
   - Sanitizer reports are authoritative — don't dismiss them as noise.
5. Install missing build deps (apt, pecl) without asking; mention what
   you added in your reply.
6. Report sanitizer findings verbatim (SUMMARY line plus the top of the
   stack) so the user can grep for them.
MD

# Token is supplied via -e CLAUDE_CODE_OAUTH_TOKEN=...
# IS_SANDBOX=1 so --dangerously-skip-permissions runs as root
ENV CLAUDE_CODE_OAUTH_TOKEN="" \
    IS_SANDBOX=1
WORKDIR /workspace

CMD ["claude", "--dangerously-skip-permissions", "--effort", "xhigh"]
