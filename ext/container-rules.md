# PHP extension scanning container

The checkout is at `/workspace/<project>`. Locate it, then work from that
directory. The container provides unrestricted root access for package
installation and file editing.

Keep every persistent result in the findings:

- Maintain `/workspace/findings.md` as the complete report. Create it at the
  start, update it as evidence develops, and record the scope and checks when
  there are no findings.
- When validating reports, include a `Special cases` section. Record every
  confirmed behavior excluded from security classification by the target's
  `SECURITY.md`, cite the applicable policy, explain the exclusion, and state
  whether it remains an ordinary bug. Keep policy exclusions distinct from
  disproved or unreproduced claims.
- Put optional PoCs, inputs, or large supporting output in
  `/workspace/findings/` when they do not fit reasonably in the report.
- Put files in the checkout when they are intended source changes, tests, or
  fixtures.
- Use `/tmp` for disposable work. Summarize useful results in `findings.md` or
  move supporting files into `findings/` before finishing.

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

- Install dependencies and tools freely. Inspect `config.m4`, configure and
  build scripts, test bootstraps, and CI hooks for malicious behavior before
  executing them. Then initialize a standard extension build with `phpize` and
  `./configure`, and run `make`.
- Record the PHP version, `/opt/php-src` commit, configure options, SAPI,
  extension commit, compiler, linked library versions, and relevant ini values.
  Reproduce on the affected supported PHP branch as well as the current branch.
- Read the target's `SECURITY.md`. For php-src, apply
  `/opt/php-src/SECURITY.md`: establish a plausible attacker-controlled path
  across a security boundary before assigning security impact. Use its private
  reporting channel for unpublished findings.
- Audit every attacker-controlled length, offset, count, allocation, copy, and
  terminator for overflow, truncation, signedness, embedded NUL bytes, partial
  reads, and platform-width differences.
- Compare stubs and generated arginfo with the C implementation: accepted and
  nullable types, by-reference parameters, return initialization, and error and
  exception behavior.
- Audit quoting, escaping, canonicalization, header parsing, archive paths,
  cryptographic verification, and serialization as security contracts. Propagate
  external-library failures and authoritative output lengths.
- Trace ownership of each `zval`, `zend_string`, `HashTable`, object, resource,
  and external-library buffer. Check refcounts, copy-on-write separation,
  request and persistent allocation, module and request shutdown, and ZTS
  globals.
- Treat calls into userland as reentrancy points. Callbacks, destructors,
  autoloading, error handlers, conversions, and object handlers may release or
  mutate values and hash tables held by C code. Revalidate borrowed pointers and
  iteration state afterward.
- Check every exception, bailout, allocation failure, parser failure, and
  partially initialized object path for balanced cleanup and valid return
  values. Exercise repeated construction, destruction, cloning, serialization,
  and request shutdown.
- Exercise persistent state across multiple requests. For shared and ZTS state,
  use a threaded SAPI or harness and verify module-global access. For immutable
  opcache data, run with `opcache.protect_memory=1`.
- Run the project's PHPT suite. Search logs for `AddressSanitizer:`,
  `UndefinedBehaviorSanitizer:`, and `runtime error:`; the test summary alone
  can miss sanitizer failures.
- Fuzz parsers and binary decoders with valid, truncated, oversized, recursive,
  and malformed inputs. Prefer a Clang libFuzzer harness for focused native
  parsing; use php-src's fuzzing SAPI for engine-integrated targets. Preserve
  useful minimized inputs in `findings.md` or `/workspace/findings/`.
- For production testing, copy the source outside `/workspace` and build a
  second object tree, for example:

   ```sh
   cp -a "$PWD" /tmp/ext-prod
   cd /tmp/ext-prod
   prod-env sh -c 'phpize && ./configure && make -j"$(nproc)"'
   ```

- `php-prod` uses stock `php.ini-production`. For visible diagnostic output,
  run `php-prod -d display_errors=1 -d error_reporting=E_ALL`.
- Reproduce crashes under `gdb --args php ...` and collect `bt full`. Check
  Zend ownership, reference counting, and allocator behavior against
  `/opt/php-src`.
- Report the smallest reproducer, exact command, sanitizer summary, relevant
  stack frames, attacker prerequisites, affected versions, and observed impact.
  Classify the memory defect separately from its security impact and redact
  credentials, personal data, and production secrets.
- Install required build dependencies and report what you installed.
