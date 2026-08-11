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

- `CLAUDE_CODE_OAUTH_TOKEN`, required for the `claude-*` containers.

- `CODEX_ACCESS_TOKEN`, required for the `codex-*` containers. Business and Enterprise workspaces only.

- `CODEX_AUTH_JSON`, the alternative on a personal account: run `codex login` once on the host, then pass `"$(cat ~/.codex/auth.json)"`.

- `GH_TOKEN`, optional. GitHub CLI auth avoids running into rate limits when looking up data. Use a fine-grained [PAT](https://github.com/settings/personal-access-tokens). Read-only access for exclusively public repos is a good default.

### Mount

The container assumes the code to scanned to exist in `/workspace`

## Build

```
./php/build.sh
./ext/build.sh
./go/build.sh
```

## Run

Mount the current folder to do scanning work with:

Containers:
- `claude-php`, `codex-php`
- `claude-ext`, `codex-ext`
- `claude-go`, `codex-go`

`./run.sh <container>` mounts `$PWD`, passes whichever token the container needs, and starts the agent.

Example:

```shell
docker run --rm -it \
    -v "$PWD:/workspace" \
    -e CLAUDE_CODE_OAUTH_TOKEN=sk-ant-... \
    -e GH_TOKEN=github_pat_... \
    claude-php
```
