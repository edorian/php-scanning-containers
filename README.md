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

- `CLAUDE_INSTALL_BUST`: force the daily agent install layers to refresh.
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

For Codex Business or Enterprise, export `CODEX_ACCESS_TOKEN`. For a personal
account, log in on the host and pass the resulting auth file:

```sh
codex login
export CODEX_AUTH_JSON="$(cat ~/.codex/auth.json)"
```

Optionally set `GH_TOKEN` for authenticated GitHub CLI access. A read-only,
fine-grained [personal access token](https://github.com/settings/personal-access-tokens)
is sufficient for public repositories.

## Run

`run.sh` mounts the current directory at `/workspace`, forwards the relevant
agent credentials, and starts the image's default agent. Use this layout:

```text
/workspace/<project>
/workspace/findings.md
/workspace/findings/     # optional supporting files
```

`findings.md` contains the complete report. Use `findings/` only when supporting
files do not fit reasonably in the report.

```sh
./run.sh claude-php
./run.sh codex-ext
```

Pass a command to replace the agent, or set `WORKSPACE` to mount another
workspace directory:

```sh
./run.sh codex-ext bash
WORKSPACE=/path/to/workspace ./run.sh claude-go
```

Equivalent direct Docker invocation:

```sh
docker run --rm -it \
  -v "$PWD:/workspace" \
  -e CLAUDE_CODE_OAUTH_TOKEN \
  -e GH_TOKEN \
  claude-php
```
