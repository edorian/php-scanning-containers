# PHP scanning container

PHP analysis sandbox. Running as root with approvals disabled
(`claude --dangerously-skip-permissions`, `codex --yolo`), so run shell
commands, write files, and install packages freely.

## Layout

- `/workspace` — target codebase (host mount). Start here.
- `/usr/local/php` — PHP built from `php-src` master; `php`, `phpize`,
  `php-config`, `php-fpm` on PATH.
- `/opt/php-src` — PHP source tree, build deps installed (rebuildable).
- `composer`, `gh`, `semgrep`, `zizmor`, `jq`, `rg`, `fd` — on PATH.
  `gh` auths from `$GH_TOKEN`.

Output that should persist goes into /workspace

## Rules

1. Back every claim with a command you ran in the container. Prefer running
   things (`php -l`, `composer validate`, `vendor/bin/phpunit`, `gh …`) over
   static reasoning.
2. Bootstrap before analyzing: if `composer.json` exists but `vendor/` is
   missing (or the lock is stale), run `composer install`/`update`. Same
   for any obvious build step the project needs.
3. Install missing tools (apt, `composer global require`, pecl) without
   asking; mention in your reply what you added.
4. Before handing back a patch, discover the project's QA tools (composer
   scripts, `phpcs.xml`, `phpstan.neon`, `psalm.xml`, `rector.php`,
   `.php-cs-fixer.php`, `phpunit.xml`, CI configs) and run the ones that
   apply against the change. Fix what they flag, or explain why not.
   Report results.
