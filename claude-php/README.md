# claude-php

Scanning container for PHP userland.

PHP is built from source with all major extensions, plus Composer, Claude Code, and the GitHub CLI.

## Build

```bash
docker build -t claude-php .
```

## Auth

`-e CLAUDE_CODE_OAUTH_TOKEN` (required) and `-e GH_TOKEN` (optional) - see the root [`README.md`](../README.md).

## Run

Mounts the current folder and launches Claude Code.

```bash
docker run --rm -it \
    -v "$PWD:/workspace" \
    -e CLAUDE_CODE_OAUTH_TOKEN \
    -e GH_TOKEN \
    claude-php
```

## Working on PHP itself

Source tree at `/opt/php-src`, build deps still installed:

```bash
cd /opt/php-src && git pull && ./buildconf --force && ./configure ... && make -j"$(nproc)" && make install
```
