## PHP environment

- `php`, `phpize`, `php-config`, and `php-fpm` use the PHP 8.5.10 release NTS
  build in `/usr/local/php`.
- PHP source and build dependencies are in `/opt/php-src`.
- `composer` and `zizmor` are on `PATH`.

Use this release NTS build for application and library analysis, dependency
audits, tests, and static checks. Route PHP core and C-extension memory-safety
work to the instrumented `claude-ext` or `codex-ext` image.

## PHP rules

- Treat Composer plugins and scripts as hooks to inspect. Start Composer
  bootstrap with `composer install --no-plugins --no-scripts`, then enable
  reviewed hooks.
- Install the versions in `composer.lock`. Update the dependency graph when the
  task specifically requires it.
- Include Composer scripts when discovering the project's checks.
- Evaluate memory-safety reports in the instrumented extension image and
  report the sanitizer result.

## Security review

- Define the attacker, entry point, trust boundary, required privileges and
  configuration, and concrete confidentiality, integrity, or availability
  impact. Include a minimal end-to-end reproducer with every finding.
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
