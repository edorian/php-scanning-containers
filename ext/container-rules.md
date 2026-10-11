## PHP builds

This image has two separate PHP builds:

| Command | Build | Prefix |
|---|---|---|
| `php`, `phpize`, `php-config`, `php-fpm` | Debug, ZTS, ASan, UBSan | `/usr/local/php` |
| `php-prod` | Release, NTS | `/usr/local/php-prod` |

Build a separate extension `.so` for each PHP build. Use the instrumented build
to find memory and undefined behavior, then use the release build to establish
production impact. Never share an object tree between the two builds.

The default `phpize` and `php-config` belong to the instrumented build. Prefix
every release build command, including `phpize`, with `prod-env`. Always label
results with the build that produced them.

`/opt/php-src` contains the configured instrumented source tree. Read its
`CODING_STANDARDS.md` before writing PHP core code.

## Toolchain

- Sanitizer compile and runtime settings are exported in the environment. See
  the live values with `env | grep -E 'FLAGS|SAN_|USE_ZEND_ALLOC'`.
- The instrumented build uses `USE_ZEND_ALLOC=0`. Leak detection is disabled in
  `ASAN_OPTIONS`; enable it explicitly for leak investigations. UBSan stops at
  its first finding.
- PHP uses GCC's ASan runtime. Use GCC for extensions loaded into `php`, and use
  Clang for standalone or libFuzzer harnesses.
- Use the release build for Valgrind; do not combine Valgrind with ASan.
- `prod-env` selects the release tools and removes sanitizer settings.
- `php-prod` uses `php.ini-production`. Enable `display_errors` when a
  reproducer needs visible diagnostics.

GDB, Valgrind, strace, Composer, and zizmor are available.

## PHP Extension workflow

1. **Build the target correctly**
   - Inspect `config.m4` and generated configure scripts before running them.
   - Use the normal `phpize`, `./configure`, and `make` flow for the instrumented
     build.
   - Build the release variant from a separate source copy under `prod-env`.
   - Load each extension only into the PHP build it was compiled for.

2. **Exercise the instrumented build first**
   - Run the relevant PHPTs and project tests with the instrumented build.
   - Search test logs for `AddressSanitizer:`, `UndefinedBehaviorSanitizer:`, and
     `runtime error:`. Test summaries can miss sanitizer output.
   - Reduce a failure to the smallest reliable reproducer.
   - Rebuild and run that reproducer with `php-prod` when assessing production
     impact.

3. **Review PHP-specific failure modes**
   - Audit untrusted lengths, offsets, counts, allocations, copies, terminators,
     and authoritative library output lengths.
   - Track ownership, reference counts, and lifetimes for Zend values and
     external buffers across success, exception, bailout, and cleanup paths.
   - Treat callbacks, destructors, autoloading, conversions, and object handlers
     as reentrancy points. Revalidate borrowed pointers and iteration state after
     invoking user code.
   - Compare stubs and generated arginfo with the C implementation, including
     nullable and by-reference parameters, return initialization, and errors.

4. **Test state that outlives one call**
   - Exercise persistent state across requests and use a threaded SAPI for ZTS
     or shared-state findings.
   - Use `opcache.protect_memory=1` when checking for writes to immutable opcache
     data.
   - Fuzz parsers and binary decoders when they are part of the exposed surface.

5. **Preserve enough evidence to reproduce the result**
   - Apply `/opt/php-src/SECURITY.md` when classifying php-src findings.
   - Record the PHP and target revisions, build, configure options, compiler,
     linked libraries, relevant ini settings, and exact commands.
   - For crashes, capture the sanitizer output and a `bt full` backtrace in GDB.
   - Keep the smallest reproducer and describe the memory defect separately from
     its security impact.
