# claude-php

One container. `php-src` master built from source with all major extensions, plus Composer and Claude Code.

## Build

```bash
docker build -t claude-php .
```

## Run

Mount a folder and drop into a shell with `php`, `composer`, `claude` on `PATH`:

```bash
docker run -it --rm \
    -e CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat-... \
    -v "$PWD:/workspace" \
    claude-php
```

Run Claude Code directly instead of bash:

```bash
docker run -it --rm \
    -e CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat-... \
    -v "$PWD:/workspace" \
    claude-php claude
```

Run a one-off PHP script:

```bash
docker run --rm -v "$PWD:/workspace" claude-php php script.php
```

## Working on PHP itself

Source tree at `/opt/php-src`, build deps still installed:

```bash
cd /opt/php-src && git pull && ./buildconf --force && ./configure ... && make -j"$(nproc)" && make install
```
