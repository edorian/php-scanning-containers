#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

BUST=${CLAUDE_INSTALL_BUST:-$(date +%Y-%m-%d)}

docker build --target claude \
    --build-arg CLAUDE_INSTALL_BUST="$BUST" -t claude-ext .
docker build --target codex \
    --build-arg CODEX_INSTALL_BUST="$BUST" \
    --build-arg CODEX_VERSION="${CODEX_VERSION:-}" -t codex-ext .

IMAGE=""
check() {
    printf "\n"'==> [%s] %s\n' "$IMAGE" "$1"; shift
    docker run --rm --entrypoint "" "$IMAGE" "$@"
}

shared_checks() {
    check "login shell PATH" bash -lc 'command -v php'
    check "php"            php --version
    check "php debug"      sh -c 'php -v | grep -qi DEBUG || { echo "not a debug build"; exit 1; }'
    check "php zts"        sh -c 'php -i | grep -q "Thread Safety => enabled"'
    check "php asan"       sh -c 'php -i | grep -q -- "--enable-address-sanitizer"'
    check "php ubsan"      sh -c 'php -i | grep -q -- "--enable-undefined-sanitizer"'
    # The sanitizer runtimes must actually be linked in, not merely configured:
    # a configure flag that silently failed to take is exactly the failure mode
    # that makes "no ASan report" look like "no bug".
    check "php asan linked" sh -c '
        ldd /usr/local/php/bin/php | grep -q libasan || { echo "no libasan in php"; exit 1; }
        ldd /usr/local/php/bin/php | grep -q libubsan || { echo "no libubsan in php"; exit 1; }
    '
    check "phpize"         phpize --version
    check "php-config"     php-config --configure-options

    # The other half of the pair. If any of this drifts, "confirmed against
    # production PHP" is a lie.
    check "php-prod"       php-prod --version
    check "php-prod release" sh -c '
        php-prod -i | grep -q "Debug Build => no"         || { echo "php-prod is a debug build"; exit 1; }
        php-prod -i | grep -q "Thread Safety => disabled" || { echo "php-prod is ZTS"; exit 1; }
        if php-prod -i | grep -q -- "--enable-address-sanitizer"; then
            echo "php-prod was configured with a sanitizer"; exit 1
        fi
        if ldd /usr/local/php-prod/bin/php | grep -Eq "libasan|libubsan"; then
            echo "php-prod links a sanitizer runtime"; exit 1
        fi
        echo "release, NTS, uninstrumented"
    '
    # prod-env must scrub the image-wide sanitizer flags, else extensions built
    # for the production PHP come out instrumented and abort when loaded.
    check "prod-env scrubs flags" sh -c '
        left=$(prod-env env | grep -E "^(CFLAGS|CXXFLAGS|LDFLAGS|ASAN_OPTIONS|UBSAN_OPTIONS|USE_ZEND_ALLOC)=" || true)
        [ -z "$left" ] || { echo "prod-env leaked: $left"; exit 1; }
        prod-env sh -c "command -v php-config" | grep -q "^/usr/local/php-prod/" \
            || { echo "prod-env PATH does not front-load the release build"; exit 1; }
    '
    check "same extension set" sh -c '
        php -m > /tmp/mods-asan; php-prod -m > /tmp/mods-prod
        diff /tmp/mods-asan /tmp/mods-prod && echo "identical" \
            || { echo "extension sets diverge between the two builds"; exit 1; }
    '
    check "composer"       composer --version
    check "gh"             gh --version
    check "gdb"            gdb --version
    check "valgrind"       valgrind --version
    check "gcc"            gcc --version
    check "clang"          clang --version
    check "lld"            ld.lld --version
    check "llvm-symbolizer" llvm-symbolizer --version
    check "clang-tidy"     clang-tidy --version

    # Catches missing compiler-rt / broken symbolizer paths before they bite
    # during real extension work.
    check "gcc asan e2e"   sh -c '
        cat > /tmp/uaf.c <<EOF
#include <stdlib.h>
int main(void){ char *p=malloc(4); free(p); return p[0]; }
EOF
        gcc -fsanitize=address,undefined -g /tmp/uaf.c -o /tmp/uaf-gcc
        out=$(/tmp/uaf-gcc 2>&1 || true)
        echo "$out" | grep -q "AddressSanitizer" || { echo "gcc asan did not fire:"; echo "$out"; exit 1; }
    '
    check "clang asan e2e" sh -c '
        cat > /tmp/uaf.c <<EOF
#include <stdlib.h>
int main(void){ char *p=malloc(4); free(p); return p[0]; }
EOF
        clang -fsanitize=address,undefined -g /tmp/uaf.c -o /tmp/uaf-clang
        out=$(/tmp/uaf-clang 2>&1 || true)
        echo "$out" | grep -q "AddressSanitizer" || { echo "clang asan did not fire:"; echo "$out"; exit 1; }
    '

    # The workflow the image exists for, end to end. Catches a broken
    # prod-env, a mismatched phpize prefix, or a release build that quietly
    # inherited the sanitizer CFLAGS.
    check "dual-abi ext e2e" sh -c '
        set -e
        php /opt/php-src/ext/ext_skel.php --ext probe --vendor smoke --dir /tmp > /dev/null
        cp -a /tmp/probe /tmp/probe-prod

        cd /tmp/probe
        phpize > /dev/null && ./configure --quiet > /dev/null && make -j"$(nproc)" > /dev/null 2>&1
        ldd modules/probe.so | grep -q libasan || { echo "instrumented .so is not linked to libasan"; exit 1; }
        php -d extension=/tmp/probe/modules/probe.so --ri probe > /dev/null
        echo "asan: built, linked to libasan, loads into php"

        cd /tmp/probe-prod
        prod-env sh -c "phpize > /dev/null && ./configure --quiet > /dev/null && make -j\"\$(nproc)\" > /dev/null 2>&1"
        if ldd modules/probe.so | grep -Eq "libasan|libubsan"; then
            echo "production .so leaked sanitizer linkage"; exit 1
        fi
        php-prod -d extension=/tmp/probe-prod/modules/probe.so --ri probe > /dev/null
        echo "prod: built, uninstrumented, loads into php-prod"

        rm -rf /tmp/probe /tmp/probe-prod
    '

    check "jq"             jq --version
    check "rg"             rg --version
    check "fd"             fd --version
    check "semgrep"        semgrep --version
    check "zizmor"         zizmor --version
    check "php-src"        test -d /opt/php-src
}

IMAGE=claude-ext
shared_checks
check "claude"         claude --version
check "CLAUDE.md"      test -s /root/.claude/CLAUDE.md
check "settings.json"  jq -r '"  model: \(.model)\n  effort: \(.effortLevel)"' /root/.claude/settings.json

IMAGE=codex-ext
shared_checks
check "codex"          codex --version
check "codex --yolo"   codex --yolo --version
check "AGENTS.md"      test -s /root/.codex/AGENTS.md
printf "\n"'==> [%s] CODEX_AUTH_JSON\n' "$IMAGE"
docker run --rm -e CODEX_AUTH_JSON='{"probe":true}' codex-ext sh -c 'cat /root/.codex/auth.json'

echo "OK"
