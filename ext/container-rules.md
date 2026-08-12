# PHP extension scanning container

Analyze the project in `/workspace`. The container provides unrestricted root
access for package installation and file editing. Keep persistent output under
`/workspace`.

## PHP builds

- `php`, `phpize`, `php-config`, and `php-fpm` use the debug, ZTS, ASan, and
  UBSan build in `/usr/local/php`. Use it to detect memory and undefined
  behavior bugs.
- `php-prod` is the release NTS CLI in `/usr/local/php-prod`. Use
  `prod-env COMMAND` for its other tools. Use this build to test production
  impact.
- `/opt/php-src` contains PHP source configured for the sanitizer build. Read
  `/opt/php-src/CODING_STANDARDS.md` before generating PHP core code.

The builds use different ABIs, so compile a separate `.so` for each. Use `php`
results for memory-safety claims and `php-prod` results for production-impact
claims. Label every result with the build that produced it.

## Toolchain

- The image exports sanitizer compile and runtime settings. Inspect them with
  `env | grep -E 'FLAGS|SAN_|USE_ZEND_ALLOC'`.
- Use GCC for extensions loaded into the GCC-built PHP process. Mixing Clang's
  ASan runtime into that process can abort. Use Clang for standalone harnesses
  and libFuzzer targets.
- `prod-env` selects and configures the release toolchain. Use it for every
  production build command.
- GDB, Valgrind, strace, Composer, Semgrep, zizmor, `gh`, `jq`, `rg`, and `fd`
  are installed. Run Valgrind and ASan separately. `gh` uses `GH_TOKEN`.

## Workflow

- Support claims with commands run in the container. Build the extension
   before analyzing it; initialize a standard extension build with `phpize` and
   `./configure`, then run `make`.
- Run the project's PHPT suite. Search logs for `AddressSanitizer:`,
   `UndefinedBehaviorSanitizer:`, and `runtime error:`; the test summary alone
   can miss sanitizer failures.
- For production testing, copy the source outside `/workspace` and build a
   second object tree, for example:

   ```sh
   cp -a /workspace /tmp/ext-prod
   cd /tmp/ext-prod
   prod-env sh -c 'phpize && ./configure && make -j"$(nproc)"'
   ```

- `php-prod` uses stock `php.ini-production`. For visible diagnostic output,
   run `php-prod -d display_errors=1 -d error_reporting=E_ALL`.
- Reproduce crashes under `gdb --args php ...` and collect `bt full`. Check
   Zend ownership, reference counting, and allocator behavior against
   `/opt/php-src`.
- Treat sanitizer findings as bugs. Report the summary line and the relevant
   top stack frames, plus the exact reproducer.
- Install required build dependencies and report what you installed.
