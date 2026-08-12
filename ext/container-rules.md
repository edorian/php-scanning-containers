# PHP extension scanning container

PHP **extension** analysis sandbox. Running as root with approvals
disabled (`claude --dangerously-skip-permissions`, `codex --yolo`), so run
shell commands, write files, and install packages freely.

## What's special about this image

**Two PHP builds**, so both halves of a security claim can be tested:

- `php` — debug + ZTS + AddressSanitizer + UndefinedBehaviorSanitizer.
  Catches memory errors, leaks, UB, and refcount/object lifetime bugs.
  ZTS means globals must go through the `ZEND_TSRMG` accessors — a `.so`
  that stashes state in plain C globals will build and then misbehave
  under threads.
- `php-prod` — release, NTS, uninstrumented, stock `php.ini-production`.
  A stand-in for what people actually run.

### Which build proves what

This is the most important thing to get right in this image, because the
two directions are **not symmetric**:

- **A memory-safety bug is proved under `php`** (ASan/UBSan), never under
  `php-prod`. A release build silently tolerates uninitialised reads,
  small out-of-bounds accesses, and use-after-frees that land on
  unrecycled memory. "I ran it under `php-prod` and nothing crashed" does
  **not** refute a claimed memory bug — do not close a report on that
  basis. Under ASan the same access is flagged every time.
- **Exploitability is proved under `php-prod`**, never under `php`.
  Sanitizer builds change heap layout, add red zones, disable the Zend
  allocator (`USE_ZEND_ALLOC=0`) and drop optimisation, so what an
  overflow reaches there says little about what it reaches in production.

A complete finding reproduces under `php` **with a sanitizer report**, and
shows a concrete effect under `php-prod`. Report which build each result
came from — an unlabelled "it crashed" is not actionable.

## Layout

- `/workspace` — target extension source (host mount). Start here.
- `/usr/local/php` — debug+ZTS+ASan+UBSan PHP. `php`, `phpize`,
  `php-config`, `php-fpm` on PATH and all resolving to this build, so a
  `.so` you build here links against the matching Zend ABI and is
  instrumented. `php -v` reports `(DEBUG)` plus sanitizer config.
- `/usr/local/php-prod` — release NTS PHP. Reach it with `php-prod`
  (the CLI) or `prod-env CMD…` (anything else — `phpize`, `configure`,
  `make`, `php-fpm`). `prod-env` front-loads its `bin`/`sbin` on PATH and
  clears `CFLAGS`/`LDFLAGS`/`*SAN_OPTIONS`/`USE_ZEND_ALLOC`; without it a
  `.so` built for this PHP comes out instrumented and aborts on load.
- `/opt/php-src` — PHP source tree, build deps installed, left configured
  for the sanitizer build. Useful for reading Zend internals
  (`Zend/zend_*.h`) when triaging crashes.
- `composer`, `gh`, `gdb`, `valgrind`, `strace`, `semgrep`, `zizmor`,
  `jq`, `rg`, `fd` — on PATH.
  (Valgrind cannot be combined with ASan — pick one per run.)
  `gh` auths from `$GH_TOKEN`.
- Both **gcc** (default `cc`) and **clang** (with `lld`, `llvm`,
  `clang-tidy`, `clang-format`, `libclang-rt-14-dev`, `libc++`) on PATH.
  `llvm-symbolizer` is available so clang's ASan/UBSan reports
  symbolize cleanly.

### Code generation

Read /opt/php-src/CODING_STANDARDS.md

Output that should persist goes into /workspace

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

Sanitizer `CFLAGS`/`CXXFLAGS`/`LDFLAGS` and the `USE_ZEND_ALLOC` /
`ASAN_OPTIONS` / `UBSAN_OPTIONS` runtime knobs are pre-exported to match
what PHP itself was built with, so `phpize && ./configure && make` picks
them up. Read the current values with `env | grep -E 'FLAGS|SAN_'` —
that is the canonical source, not this file.

They are exported image-wide, which is why `prod-env` exists: it clears
all of them before running its command, so a build for `php-prod` is a
plain uninstrumented one. Anything you build for the production PHP must
go through `prod-env`.

Why the non-obvious ones are set:

- `-fno-sanitize=object-size` — PHP's `zend_function` union violates
  strict object-size; php-src sets this itself.
- `-DZEND_TRACK_ARENA_ALLOC` — changes how Zend's arena allocator is
  compiled. Extensions need the same definition as the core, or the
  allocator macros go inconsistent.
- `USE_ZEND_ALLOC=0` — disables Zend's arena so ASan sees every alloc.
- `detect_leaks=0` — PHP has known startup leaks that drown signal. Flip
  to `=1` once you have a focused suspect.
- `-fno-sanitize-recover=undefined` — compiled in, so UB **aborts** on
  first hit. Same as php-src CI.

## Rules

1. Back every claim with a command you ran in the container. `php -l`,
   `make test`, `gdb --args php …`, parsing ASan reports — prefer
   running things over static reasoning.
2. Build the extension before analyzing. If `config.m4` exists but no
   `Makefile`, run `phpize && ./configure && make`.
3. State which PHP produced every result — `php` or `php-prod`. Never
   refute a memory-safety claim with a clean `php-prod` run; that build
   cannot detect one. If you could not reproduce something, say which
   build you tried and what you would need to go further, rather than
   calling it not reproducible.
4. To test against production, build a second `.so` — the two PHPs are
   ABI-incompatible, so the instrumented one will not load into
   `php-prod`. Use a scratch copy so the object trees don't collide:
   `cp -a /workspace /tmp/ext-prod && cd /tmp/ext-prod &&
   prod-env sh -c 'phpize && ./configure && make -j"$(nproc)"'`
5. `php-prod` runs stock `php.ini-production`: `display_errors=Off`,
   `zend.assertions=-1`. A repro that prints nothing there is very likely
   the ini — re-run with `php-prod -d display_errors=1 -d
   error_reporting=E_ALL` before drawing any conclusion.
6. Run the project's `.phpt` tests if any exist. A clean `make test`
   summary doesn't mean a clean sanitizer run — grep the test logs for
   `AddressSanitizer:` / `UndefinedBehaviorSanitizer:` / `runtime error:`.
7. When triaging a crash:
   - Re-run under `gdb --args php -d extension=… script.php`, `bt full`.
   - Cross-reference with `/opt/php-src` headers for `ZVAL_*`,
     `Z_ADDREF_P`, `OBJ_RELEASE`, arena vs. emalloc usage.
   - Sanitizer reports are authoritative — don't dismiss them as noise.
8. Install missing build deps (apt, pecl) without asking; mention what
   you added in your reply.
9. Report sanitizer findings verbatim (SUMMARY line plus the top of the
   stack) so the user can grep for them.
