# PHP scanning container

PHP analysis sandbox. Running as root with approvals disabled
(`claude --dangerously-skip-permissions`, `codex --yolo`), so run shell
commands, write files, and install packages freely.

## Layout

- `/workspace` — target codebase (host mount). Start here.
- `/usr/local/php` — PHP built from the `php-8.5.7` tag; `php`, `phpize`,
  `php-config`, `php-fpm` on PATH.
- `/opt/php-src` — PHP source tree, build deps installed (rebuildable).
- `composer`, `gh`, `semgrep`, `zizmor`, `jq`, `rg`, `fd` — on PATH.
  `gh` auths from `$GH_TOKEN`.

Output that should persist goes into /workspace

## This is a release build — no debugger instrumentation

`php -v` reports `(NTS)` with no `DEBUG`, and nothing here is compiled
with AddressSanitizer or UndefinedBehaviorSanitizer. That is deliberate:
this image exists to run userland PHP the way production runs it.

The consequence for security work: **this container cannot refute a
memory-safety claim.** A release build silently tolerates uninitialised
reads, small out-of-bounds accesses, and use-after-frees that land on
unrecycled memory, so a clean run here does not refute a claimed memory
bug — it may simply have missed it. Reproducing a crash here is still
meaningful; failing to is not.

If a report alleges a memory-safety bug in PHP itself or in a C
extension, hand it to the **`claude-ext` / `codex-ext`** image, which
carries a debug+ASan+UBSan `php` alongside a release `php-prod`. Do not
close such a report from this container.

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
5. Never write off a memory-safety claim because nothing crashed here —
   see above. Say the check needs the `ext` image and leave the report
   open.
