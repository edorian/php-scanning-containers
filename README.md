Ephemeral containers to work with untrusted PHP, PHP-extension, and Go source code

# Overview

For details the README.md files in the subfolders

## Setup

Get a token for your Claude account

```
claude setup-token
```

### Auth

Tokens are shared `ENV` (`-e`)

- `CLAUDE_CODE_OAUTH_TOKEN`, required.

- `GH_TOKEN`, optional. GitHub CLI auth avoids running into rate limits when looking up data. Use a fine-grained [PAT](https://github.com/settings/personal-access-tokens). Read-only access for exclusively public repos is a good default.

### Mount

The container assumes the code to scanned to exist in `/workspace`

## Build

```
./claude-php/build.sh
./claude-ext/build.sh
./claude-go/build.sh
```

## Run

Mount the current folder to do scanning work with:

Containers:
- `claude-php`
- `claude-ext`
- `claude-go`

Example:

```shell
docker run --rm -it \
    -v "$PWD:/workspace" \
    -e CLAUDE_CODE_OAUTH_TOKEN=sk-ant-... \
    -e GH_TOKEN=github_pat_... \
    claude-php
```
