# claude-ext

One container. `php-src` master built **debug + ZTS + AddressSanitizer +
UndefinedBehaviorSanitizer**, ready for PHP C extensions to be built and
fuzzed against it. Composer, Claude Code, `gdb`, `valgrind`, `strace` on
PATH.

## Build

```bash
./build.sh        # docker build -t claude-ext . + smoke checks
```

## Run

Mount an extension source tree and let Claude Code drive:

```bash
docker run -it --rm \
    -e CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat-... \
    -v "$PWD:/workspace" \
    claude-ext
```

Drop into a shell instead:

```bash
docker run -it --rm -v "$PWD:/workspace" --entrypoint bash claude-ext
```

Build + test a single extension:

```bash
docker run --rm -v "$PWD:/workspace" --entrypoint bash claude-ext -c '
    cd /workspace &&
    phpize &&
    ./configure --enable-myext &&
    make -j"$(nproc)" &&
    make test'
```

## What's in the image

| Path                | What                                                |
|---------------------|-----------------------------------------------------|
| `/usr/local/php`    | Debug+ZTS+ASan+UBSan PHP install                    |
| `/opt/php-src`      | PHP source tree (Zend headers, build deps)          |
| `/workspace`        | Host mount — your extension source                  |
| `php`, `phpize`, `php-config`, `php-fpm` | On PATH                        |
| `composer`, `gh`, `claude`               | On PATH                        |
| `gdb`, `valgrind`, `strace`              | On PATH                        |

## Sanitizer setup

The image pre-exports the flags that matter, so `phpize && ./configure`
inside any extension picks them up:

```
CFLAGS   = -fsanitize=address,undefined -fno-omit-frame-pointer \
           -fno-sanitize-recover=undefined -g -O1
CXXFLAGS = (same as CFLAGS)
LDFLAGS  = -fsanitize=address,undefined

USE_ZEND_ALLOC=0           # Zend's arena hides bugs from ASan — off.
ZEND_DONT_UNLOAD_MODULES=1  # keep module symbols for clean leak stacks.
ASAN_OPTIONS=symbolize=1:strict_string_checks=1:detect_stack_use_after_return=1:detect_leaks=0
UBSAN_OPTIONS=print_stacktrace=1:print_summary=1
```

`detect_leaks=0` by default because PHP itself has known startup leaks
that drown signal in noise. Flip to `detect_leaks=1` when you have a
focused suspect.

`-fno-sanitize-recover=undefined` makes UBSan **abort** on first hit.
That's the right default for catching bugs; set
`UBSAN_OPTIONS=halt_on_error=0` if you want to survey across many UB
sites in one run.

## Building an extension

```bash
cd /workspace
phpize
./configure --enable-myext
make -j"$(nproc)"

# Smoke test
php -d extension="$(pwd)/modules/myext.so" --ri myext

# Sanitizer-aware test run
make test TESTS="-q --show-diff"
```

`phpize` reads from `/usr/local/php` — the same debug+sanitizer build —
so the resulting `.so` is ABI-compatible and instrumented.

## Triaging a sanitizer report

ASan / UBSan write to stderr. The interesting bits:

```
==12345==ERROR: AddressSanitizer: heap-use-after-free on address ...
    #0 0x... in zif_myext_thing src/myext.c:42
    ...
SUMMARY: AddressSanitizer: heap-use-after-free src/myext.c:42 in zif_myext_thing
```

Re-run under GDB for a live session:

```bash
gdb --args php -d extension=./modules/myext.so script.php
(gdb) run
(gdb) bt full
```

Zend internals live at `/opt/php-src/Zend/` — keep them open when reading
refcount / object-lifetime crashes.

## Working on PHP itself

Source tree at `/opt/php-src`, build deps installed:

```bash
cd /opt/php-src && git pull && ./buildconf --force && ./configure ... \
  && make -j"$(nproc)" && make install
```

The Dockerfile's `./configure` line is the canonical reference for which
extensions are compiled in.
