#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# CLAUDE_INSTALL_BUST changes once per day so the claude install layer
# refreshes daily. To force a refresh mid-day, pass CLAUDE_INSTALL_BUST=<anything new>.
docker build --build-arg CLAUDE_INSTALL_BUST="${CLAUDE_INSTALL_BUST:-$(date +%Y-%m-%d)}" -t claude-ext .

check() {
    printf "\n"'==> %s\n' "$1"; shift
    docker run --rm --entrypoint "" claude-ext "$@"
}

check "php"            php --version
check "php debug"      sh -c 'php -v | grep -qi DEBUG || { echo "not a debug build"; exit 1; }'
check "php asan"       sh -c 'php -i | grep -q -- "--enable-address-sanitizer"'
check "php ubsan"      sh -c 'php -i | grep -q -- "--enable-undefined-sanitizer"'
check "phpize"         phpize --version
check "php-config"     php-config --configure-options
check "composer"       composer --version
check "gh"             gh --version
check "claude"         claude --version
check "gdb"            gdb --version
check "valgrind"       valgrind --version
check "gcc"            gcc --version
check "clang"          clang --version
check "lld"            ld.lld --version
check "llvm-symbolizer" llvm-symbolizer --version
check "clang-tidy"     clang-tidy --version

# Tiny end-to-end sanitizer smoke: build the same UAF program with gcc
# and clang under -fsanitize=address,undefined, run each, confirm both
# emit an AddressSanitizer report. Catches missing compiler-rt / broken
# symbolizer paths before they bite during real extension work.
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
check "jq"             jq --version
check "rg"             rg --version
check "fd"             fd --version
check "semgrep"        semgrep --version
#check "zizmor"         zizmor --version
check "CLAUDE.md"      test -s /root/.claude/CLAUDE.md
check "settings.json"  jq -r '"  model: \(.model)\n  effort: \(.effortLevel)"' /root/.claude/settings.json
check "php-src"        test -d /opt/php-src

echo "OK"
