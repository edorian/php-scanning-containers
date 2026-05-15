Ephemeral container to work with untrusted PHP and PHP-extension source code

# Overview

For details the README.md files in the subfolders

## Setup

Get a token for your Claude account

```
claude setup-token
```

## Build

`./claude-php/build.sh`
`./claude-ext/build.sh`

## Mount the current folder for work

```shell
docker run --rm -v .:/workspace -e CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" -it claude-php
docker run --rm -v .:/workspace -e CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" -it claude-ext
```
