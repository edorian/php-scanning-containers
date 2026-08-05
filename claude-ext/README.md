# claude-ext

Scanning container for PHP extensions.

`php-src` master built **debug + ZTS + AddressSanitizer + UndefinedBehaviorSanitizer**, ready for PHP C extensions to be built against it. Composer, Claude Code, `gdb`, `valgrind`, `strace` on PATH.

## Build

```bash
./build.sh
```

## Auth

`-e CLAUDE_CODE_OAUTH_TOKEN` (required) and `-e GH_TOKEN` (optional) - see the root [`README.md`](../README.md).

## Run

Mounts the extension source tree and launches Claude Code

```bash
docker run --rm -it \
    -v "$PWD:/workspace" \
    -e CLAUDE_CODE_OAUTH_TOKEN \
    -e GH_TOKEN \
    claude-ext
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

`CFLAGS`/`CXXFLAGS`/`LDFLAGS`, `USE_ZEND_ALLOC`, `ASAN_OPTIONS` and
`UBSAN_OPTIONS` are pre-exported in the image, so `phpize && ./configure`
inside any extension inherits the same flags PHP itself was built with.

The `ENV` blocks in the [`Dockerfile`](Dockerfile) are the canonical
list — this file deliberately doesn't copy them. To see what a live
container has:

```bash
docker run --rm --entrypoint "" claude-ext env | grep -E 'FLAGS|SAN_'
```

Two defaults worth knowing:

- `detect_leaks=0`, because PHP itself has known startup leaks that drown
  signal in noise. Flip to `detect_leaks=1` when you have a focused
  suspect.
- `-fno-sanitize-recover=undefined` makes UBSan **abort** on first hit.
  It is compiled in, so no `UBSAN_OPTIONS` setting relaxes it — to survey
  many UB sites in one run you have to rebuild without the flag.

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

## Working on PHP itself

Source tree at `/opt/php-src`, build deps installed:

```bash
cd /opt/php-src && git pull && ./buildconf --force && ./configure ... \
  && make -j"$(nproc)" && make install
```

The Dockerfile's `./configure` line is the canonical reference for which extensions are compiled in.
