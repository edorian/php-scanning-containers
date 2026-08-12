# claude-go

Scanning container for Go projects.

The current stable Go toolchain from the official tarball, plus the usual
analysis tools (`staticcheck`, `golangci-lint`, `govulncheck`, `gosec`,
`dlv`), Claude Code, and the GitHub CLI.

Build, auth and run: see the root [`README.md`](../README.md).

## What's in the image

| Path / binary                                          | What                                     |
|--------------------------------------------------------|------------------------------------------|
| `/usr/local/go`                                          | Go toolchain, including full stdlib source |
| `/root/go/bin`                                           | GOPATH bin — `go install`ed tools        |
| `/workspace`                                             | Host mount — your source                 |
| `go`, `gofmt`, `gofumpt`, `goimports`                    | Build + formatting                       |
| `staticcheck`, `golangci-lint`, `gosec`, `govulncheck`   | Static analysis, vuln scanning           |
| `gopls`, `dlv`, `gotestsum`                              | LSP, debugger, test runner               |
| `gcc`, `clang`, `gdb`, `strace`                          | cgo, sanitizer builds, debugging         |
| `gh`, `claude`, `semgrep`, `jq`, `rg`, `fd`              | On PATH                                  |

## Toolchain version

The baked-in toolchain defaults to whatever `https://go.dev/VERSION?m=text`
reports at build time. Pin it with `GO_VERSION=go1.25.0 ./build.sh`.

`GOTOOLCHAIN=auto`, so `go` downloads and uses whatever version the
project's `go.mod` requires. The baked-in version is only the floor —
inside `/workspace`, `go version` is the one that matters.

To work offline or force the baked-in toolchain:

```bash
GOTOOLCHAIN=local go build ./...
```

## Bug hunting

The race detector is the highest-value tool here and needs cgo, which is
enabled by default:

```bash
go test -race ./...
```

Go's memory sanitizers require clang, which is installed:

```bash
CC=clang go test -msan ./...   # uninitialized reads (cgo-heavy code)
CC=clang go test -asan ./...   # out-of-bounds / UAF across the cgo boundary
```

`go test -fuzz` writes crashers to `testdata/fuzz/<Target>/` in the
package directory — that is under `/workspace`, so they survive the
container. `dlv` is installed for live debugging.

## Notes

- `CGO_ENABLED=1`. Set `CGO_ENABLED=0` per-command for pure-Go static
  binaries; the race detector and the sanitizers won't work then.
- The module and build caches are inside the container, so a fresh `docker
  run` re-downloads dependencies. To keep them across runs, mount a
  volume: `-v go-mod-cache:/root/go/pkg/mod -v go-build-cache:/root/.cache/go-build`.
