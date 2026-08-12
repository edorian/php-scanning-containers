# PHP extension image

Use `claude-ext` or `codex-ext` for PHP core and C-extension work. Each image
contains two PHP builds with distinct ABIs:

| Command | Build | Use it to |
|---|---|---|
| `php` | Debug, ZTS, ASan, UBSan | Detect memory-safety and undefined-behavior bugs |
| `php-prod` | Release, NTS, stock `php.ini-production` | Test behavior under production-like conditions |

Also included: PHP source at `/opt/php-src`, Composer, GCC, Clang, GDB,
Valgrind, and strace. See the [root README](../README.md) for build,
authentication, and launch commands.

## Choose the right build

Use `php` to produce sanitizer evidence for invalid accesses. Use `php-prod` to
demonstrate effects under production allocation, optimization, and ini settings.
A complete security finding usually includes both results.

Always label results with the build that produced them.

## Build an extension

The default toolchain builds an instrumented extension for `php`:

```sh
cd /workspace
phpize
./configure --enable-myext
make -j"$(nproc)"

php -d extension="$PWD/modules/myext.so" --ri myext
make test TESTS="-q --show-diff"
```

Build a separate copy for `php-prod`; the debug/ZTS and release/NTS builds use
different ABIs and object trees:

```sh
cp -a /workspace /tmp/myext-prod
cd /tmp/myext-prod
prod-env sh -c 'phpize && ./configure --enable-myext && make -j"$(nproc)"'

php-prod -d extension="$PWD/modules/myext.so" --ri myext
prod-env make test TESTS="-q --show-diff"
```

`prod-env` selects `/usr/local/php-prod` and prepares a release build
environment. Use it for every production build command, including `phpize`.

For visible diagnostics under the production ini, enable error output:

```sh
php-prod -d display_errors=1 -d error_reporting=E_ALL repro.php
```

## Sanitizer behavior

The sanitizer flags and runtime options are exported in the image. Inspect the
live values when needed:

```sh
env | grep -E 'FLAGS|SAN_|USE_ZEND_ALLOC'
```

Notable defaults:

- Set `ASAN_OPTIONS=detect_leaks=1` for focused leak testing.
- UBSan aborts on its first finding because PHP is compiled with
  `-fno-sanitize-recover=undefined`.
- PHP itself uses GCC's ASan runtime. Build loadable extensions with GCC and
  standalone harnesses with Clang.

The [Dockerfile](Dockerfile) is the source of truth for flags and PHP configure
options.

## Rebuild PHP

`/opt/php-src` remains configured for the sanitizer build. Reconfigure and
rebuild it in place as needed. Build production PHP in a copy, use `prod-env`,
and keep the `/usr/local/php-prod` prefix. The original configure command is
available from:

```sh
php-prod -i | grep 'Configure Command'
```
