Ephemeral containers to work with agents

# Overview

Three images, each built in two variants: `claude-*` runs Claude Code, `codex-*` runs the Codex CLI.

| Containers | For | Details |
|---|---|---|
| `claude-php`, `codex-php` | PHP userland | [`php/README.md`](php/README.md) |
| `claude-ext`, `codex-ext` | PHP C extensions. `php` (debug+ZTS+ASan+UBSan) to prove a memory-safety bug, `php-prod` (release NTS) to prove it matters in production | [`ext/README.md`](ext/README.md) |
| `claude-go`, `codex-go` | Go | [`go/README.md`](go/README.md) |

Setup, auth, build and run are the same for all three and are documented below. The sub-READMEs cover only what is specific to each image.

## Setup

Get a token for your Claude or OpenAI account

```
claude setup-token
```

```
# After logging in once
$(cat ~/.codex/auth.json)
```

### Auth

Tokens are passed as `ENV` (`-e`)

- `CLAUDE_CODE_OAUTH_TOKEN`, required for the `claude-*` containers.

- `CODEX_ACCESS_TOKEN`, required for the `codex-*` containers. Business and Enterprise workspaces only.

- `CODEX_AUTH_JSON`, the alternative on a personal account: run `codex login` once on the host, then pass `"$(cat ~/.codex/auth.json)"`.

- `GH_TOKEN`, optional. GitHub CLI auth avoids running into rate limits when looking up data. Use a fine-grained [PAT](https://github.com/settings/personal-access-tokens). Read-only access for exclusively public repos is a good default.

### Mount

The container expects the code to be scanned in `/workspace`.

## Build

Each `build.sh` builds both variants of its image, then runs a set of checks against them.

```
./php/build.sh
./ext/build.sh
./go/build.sh
```

Optional build args:

- `CLAUDE_INSTALL_BUST` — the agent install layers refresh once a day. Set this to anything new to force a refresh sooner.
- `CODEX_VERSION` — pin the Codex CLI instead of taking the latest.
- `GO_VERSION` — `go/build.sh` only, see [`go/README.md`](go/README.md).

## Run

`./run.sh <container>` mounts `$PWD`, passes whichever token the container needs, and starts the agent. Mount something else with `WORKSPACE=/some/path`, or pass a command to get that instead of the agent:

```shell
./run.sh claude-php
./run.sh codex-ext bash
```

The same by hand:

```shell
docker run --rm -it \
    -v "$PWD:/workspace" \
    -e CLAUDE_CODE_OAUTH_TOKEN=sk-ant-... \
    -e GH_TOKEN=github_pat_... \
    claude-php
```
