# claude-ext

Scanning container for PHP extensions.

| Command    | Prefix                | Build                                          | Answers                                     |
|------------|-----------------------|------------------------------------------------|---------------------------------------------|
| `php`      | `/usr/local/php`      | debug + ZTS + AddressSanitizer + UndefinedBehaviorSanitizer | *Does the memory-safety bug reproduce?* |
| `php-prod` | `/usr/local/php-prod` | release, NTS, uninstrumented, `php.ini-production` | *Does the attack vector work in production?* |

Composer, `gdb`, `valgrind`, `strace` on PATH.

Build, auth and run: see the root [`README.md`](../README.md).

## Which build answers which question

The two directions are not symmetric, and using one build for both is how
false negatives get into a triage queue.

- **Proving a memory-safety bug** — use `php` (the ASan/UBSan build). A release
  build silently tolerates uninitialised reads, small out-of-bounds accesses,
  and use-after-frees that happen to land on unrecycled memory.
- **Proving exploitability** — use `php-prod`. Sanitizer builds change the heap
  layout, insert red zones, disable the Zend allocator (`USE_ZEND_ALLOC=0`) and
  drop optimisation. An overflow that reaches an interesting adjacent object
  under ASan may reach nothing under `-O2` with Zend MM, and vice versa.

A complete finding reproduces under `php` with a sanitizer report, **and** demonstrably does something under `php-prod`.

ASan/UBSan issues are still bugs worth fixing.

## What's in the image

| Path                  | What                                                       |
|-----------------------|------------------------------------------------------------|
| `/usr/local/php`      | Debug+ZTS+ASan+UBSan PHP install                           |
| `/usr/local/php-prod` | Release NTS PHP install, `php.ini-production`              |
| `/opt/php-src`        | PHP source tree (Zend headers, build deps), configured for the sanitizer build |
| `/workspace`          | Host mount — your extension source                         |
| `php`, `phpize`, `php-config`, `php-fpm` | On PATH — all the sanitizer build |
| `php-prod`, `prod-env`                   | On PATH — the release build     |
| `composer`, `gh`, `claude`               | On PATH                         |
| `gdb`, `valgrind`, `strace`              | On PATH                         |

## Reaching the production build

`php-prod` is the release CLI. `prod-env CMD…` runs anything else against that
build: it front-loads `/usr/local/php-prod/bin` onto `PATH` and clears the
sanitizer variables, which is what makes a `.so` compiled under it come out
uninstrumented.

```bash
php-prod -v                          # release CLI
prod-env php-config --configure-options
prod-env sh -c 'phpize && ./configure && make -j"$(nproc)"'
```

Clearing those variables is not optional: `CFLAGS`/`LDFLAGS` are exported
image-wide with `-fsanitize=…`, so an extension built without `prod-env` is
instrumented and aborts on load against the uninstrumented binary.

`php-prod` ships **`php.ini-production` verbatim** — that is the point of it, but
it means `display_errors=Off` and `zend.assertions=-1`. If a repro prints
nothing under `php-prod`, that is the ini, not a refutation:

```bash
php-prod -d display_errors=1 -d error_reporting=E_ALL repro.php
```

## Sanitizer setup

`CFLAGS`/`CXXFLAGS`/`LDFLAGS`, `USE_ZEND_ALLOC`, `ASAN_OPTIONS` and
`UBSAN_OPTIONS` are pre-exported in the image, so `phpize && ./configure`
inside any extension inherits the same flags the **sanitizer** PHP was built
with. `prod-env` clears them for the production build.

The `ENV` blocks in the [`Dockerfile`](Dockerfile) are the canonical
list — this file deliberately doesn't copy them. To see what a live
container has:

```bash
docker run --rm --entrypoint "" claude-ext env | grep -E 'FLAGS|SAN_'
```

Two defaults to know about:

- `detect_leaks=0`, because PHP itself has known startup leaks that drown
  signal in noise. Flip to `detect_leaks=1` when you have a focused
  suspect.
- `-fno-sanitize-recover=undefined` makes UBSan **abort** on first hit.
  It is compiled in, so no `UBSAN_OPTIONS` setting relaxes it — to survey
  many UB sites in one run you have to rebuild without the flag.

## Building an extension

The two PHPs are ABI-incompatible with each other — debug vs release and ZTS vs
NTS both change the ABI — so a `.so` has to be built once per target. Build them
in separate directories; a single tree cannot hold both object sets.

```bash
# Instrumented, against the default toolchain
cd /workspace
phpize
./configure --enable-myext
make -j"$(nproc)"

php -d extension="$PWD/modules/myext.so" --ri myext
make test TESTS="-q --show-diff"
```

```bash
# Production, in a scratch copy so the object trees don't collide
cp -a /workspace /tmp/myext-prod && cd /tmp/myext-prod
prod-env sh -c 'phpize && ./configure --enable-myext && make -j"$(nproc)"'

php-prod -d extension="$PWD/modules/myext.so" --ri myext
prod-env make test TESTS="-q --show-diff"
```

`phpize` reads from `/usr/local/php` — the same debug+sanitizer build — so the
first `.so` is ABI-compatible and instrumented. Under `prod-env`, `phpize`
resolves to `/usr/local/php-prod/bin/phpize` instead and the second `.so` is a
plain release build.

Loading the wrong `.so` into the wrong binary fails loudly (a sanitizer runtime
mismatch or a Zend module API mismatch), so a mix-up is not a silent corruption
risk — but it is not a result either. Rebuild for the target you meant.

## Working on PHP itself

Source tree at `/opt/php-src`, build deps installed. It is left configured for
the **sanitizer** build; the production build was made in a throwaway copy and
its tree is gone.

```bash
cd /opt/php-src && git pull && ./buildconf --force && ./configure ... \
  && make -j"$(nproc)" && make install
```

To rebuild the production PHP, work in a copy so you don't clobber the sanitizer
tree, and keep its prefix. `php-prod -i | grep 'Configure Command'` prints the
exact options it was built with:

```bash
cp -a /opt/php-src /tmp/php-src-prod && cd /tmp/php-src-prod && make clean
prod-env sh -c './configure --prefix=/usr/local/php-prod … && make -j"$(nproc)" && make install'
```

The Dockerfile's `PHP_COMMON_CONFIGURE` arg is the canonical reference for which
extensions are compiled in.
