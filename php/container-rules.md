## PHP environment

`php`, `phpize`, `php-config`, and `php-fpm` use the release, non-thread-safe
build in `/usr/local/php`. Check the exact version with `php --version`. The
matching configured PHP source tree is in `/opt/php-src`. Composer and zizmor
are on `PATH`.

Use this image for applications, libraries, dependency audits, and static
analysis. Use the `ext` image for PHP core, C extensions, or memory-safety work;
it provides instrumented and production builds.

## PHP rules

1. **Bootstrap Composer safely**
   - Inspect `composer.json` plugins and scripts before enabling them.
   - Start with `composer install --no-plugins --no-scripts` when dependencies
     need to be installed, then run only the hooks you have reviewed.
   - Install the versions in `composer.lock`. Do not update the dependency graph
     unless the task requires it.

2. **Check locked dependencies**
   - When `composer.lock` exists, run `composer validate --strict`,
     `composer audit --locked`, and `composer check-platform-reqs`.
   - Before reporting an advisory, confirm that it applies to the installed
     version and a reachable path in this project.

3. **Reproduce behavior in the right runtime**
   - Use the deployment SAPI and relevant ini settings for behavior that differs
     between CLI, FPM, and web requests.
   - Record the effective SAPI, ini files, extensions, and dependency versions
     when they affect the result.
   - Confirm suspected memory-safety problems in the instrumented `ext` image
     and include the sanitizer evidence.
