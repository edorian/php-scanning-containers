# PHP scanning container

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

## Environment

- `php`, `phpize`, `php-config`, and `php-fpm` use the PHP 8.5.9 release NTS
  build in `/usr/local/php`.
- PHP source and build dependencies are in `/opt/php-src`.
- `composer`, `gh`, `semgrep`, `zizmor`, `jq`, `rg`, and `fd` are on `PATH`.
  `gh` uses `GH_TOKEN`.

Use this release NTS build for application and library analysis, dependency
audits, tests, and static checks. Route PHP core and C-extension memory-safety
work to the instrumented `claude-ext` or `codex-ext` image.

## Rules

- Support claims with commands run in the container. Prefer execution over
  static inference.
- Install dependencies and tools freely. Inspect Composer plugins and scripts,
  test bootstraps, build files, and CI hooks for malicious behavior before
  executing them. Start Composer bootstrap with
  `composer install --no-plugins --no-scripts`, then enable reviewed hooks.
- Install the versions in `composer.lock`. Update the dependency graph when the
  task specifically requires it.
- Install required tools and report what you installed.
- Discover the project's checks in Composer scripts, CI, and tool configs.
  Run all checks relevant to the change, fix their findings, and report the
  results.
- Evaluate memory-safety reports in the instrumented extension image and
  report the sanitizer result.

## Security review

- Read the project's `SECURITY.md` first. Keep unpublished findings in its
  designated private reporting channel.
- Define the attacker, entry point, trust boundary, required privileges and
  configuration, and concrete confidentiality, integrity, or availability
  impact. Include a minimal end-to-end reproducer with every finding and redact
  credentials, personal data, and production secrets.
- Trace request data, headers, cookies, uploads, serialized values, database
  rows, queues, caches, environment variables, and configuration into
  authorization decisions and sensitive sinks: SQL, processes, paths, includes,
  streams, outbound URLs, templates, response headers, and deserialization.
- Test PHP-specific boundary values: arrays in scalar inputs, numeric strings,
  loose comparisons, embedded NUL bytes, invalid encodings, traversal segments,
  stream-wrapper schemes, symlinks, redirects, deep recursion, and oversized
  input.
- Review authentication and state changes for object ownership, tenant and role
  boundaries, CSRF, session fixation and rotation, reset tokens, and cookie and
  trusted-proxy settings. Review secret generation, password handling,
  cryptographic verification, error output, and security-sensitive logging.
- Run `composer validate --strict`, `composer audit --locked`, and
  `composer check-platform-reqs` when the project has a lock file. Report the
  affected package, installed version, advisory, and reachable application path.
- Record `php -v`, `php --ini`, relevant `php -i` values, enabled extensions,
  dependency versions, and SAPI. Reproduce request parsing, sessions, uploads,
  headers, and proxy behavior through the deployment-relevant SAPI and config.
