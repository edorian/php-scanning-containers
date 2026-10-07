# Agent scanning containers

Disposable Docker environments for running Claude Code or Codex against a
mounted codebase.

| Containers | Use case | Guide |
|---|---|---|
| `claude-php`, `codex-php` | PHP applications and libraries | [PHP](php/README.md) |
| `claude-ext`, `codex-ext` | PHP core and C extensions | [PHP extensions](ext/README.md) |
| `claude-go`, `codex-go` | Go projects | [Go](go/README.md) |

## Build

Each build script creates and checks both agent variants:

```sh
./php/build.sh
./ext/build.sh
./go/build.sh
```

Optional environment variables:

- `HARNESS_BUST`: force both agent install layers to refresh.
- `PHP_SRC_BUST`: force `ext/build.sh` to re-clone php-src; it refreshes daily
  by default.
- `CODEX_VERSION`: install a specific Codex release instead of the latest.
- `GO_VERSION`: set the Go version used by `go/build.sh`.
- `PHP_GIT_REF`: select the php-src tag or branch used by `php/build.sh` or
  `ext/build.sh`.

## Authenticate

For Claude Code, generate and export an OAuth token:

```sh
claude setup-token
export CLAUDE_CODE_OAUTH_TOKEN='...'
```

For Codex with a ChatGPT subscription, log in once on the host:

```sh
codex login
```

`run.sh` reads `~/.codex/auth.json`, removes its refresh token, and passes the
result into the disposable container. This needs `jq`, but no auth mount or
container login. Set `CODEX_AUTH_FILE` to use another cache file.

Optionally set `GH_TOKEN` for authenticated GitHub CLI access. A read-only,
fine-grained [personal access token](https://github.com/settings/personal-access-tokens)
is sufficient for public repositories.

## Run

`run.sh` mounts the current directory at `/workspace`, forwards credentials,
and starts the selected agent.

```sh
./run.sh claude-php
./run.sh codex-php
```

Pass a command to replace the agent, or set `WORKSPACE` to mount another
workspace directory:

```sh
./run.sh codex-php bash
WORKSPACE=/path/to/workspace ./run.sh claude-php
```

Without `run.sh`:

```sh
docker run --rm -it \
  -v "$PWD:/workspace" \
  -e CLAUDE_CODE_OAUTH_TOKEN \
  -e GH_TOKEN \
  claude-php

CODEX_AUTH_JSON="$(jq -c '.tokens.refresh_token = ""' ~/.codex/auth.json)" \
docker run --rm -it \
  -v "$PWD:/workspace" \
  -e CODEX_AUTH_JSON \
  -e GH_TOKEN \
  codex-php
```
