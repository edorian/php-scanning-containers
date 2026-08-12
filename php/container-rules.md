# PHP scanning container

Analyze the project in `/workspace`. The container provides unrestricted root
access for package installation and file editing. Keep persistent output under
`/workspace`.

## Environment

- `php`, `phpize`, `php-config`, and `php-fpm` use the PHP 8.5.7 release NTS
  build in `/usr/local/php`.
- PHP source and build dependencies are in `/opt/php-src`.
- `composer`, `gh`, `semgrep`, `zizmor`, `jq`, `rg`, and `fd` are on `PATH`.
  `gh` uses `GH_TOKEN`.

Use this release NTS build for production-like userland behavior, dependency
analysis, tests, and static checks. Route PHP core and C-extension memory-safety
work to the instrumented `claude-ext` or `codex-ext` image.

## Rules

- Support claims with commands run in the container. Prefer execution over
   static inference.
- Bootstrap the project before analysis. Bring Composer dependencies up to
   date and run required build steps.
- Install required tools and report what you installed.
- Discover the project's checks in Composer scripts, CI, and tool configs.
   Run all checks relevant to the change, fix their findings, and report the
   results.
- Evaluate memory-safety reports in the instrumented extension image and
   report the sanitizer result.
