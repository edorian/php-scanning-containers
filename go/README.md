# Go image

Use `claude-go` or `codex-go` for Go projects. The image includes the Go
toolchain and standard library source, cgo support, GCC, Clang, Delve, and these
project tools:

- `gofmt`, `gofumpt`, `goimports`
- `staticcheck`, `golangci-lint`, `gosec`, `govulncheck`
- `gopls`, `gotestsum`, `semgrep`

See the [root README](../README.md) for build, authentication, and launch
commands.

## Toolchain version

The build uses the current stable Go release unless `GO_VERSION` is set:

```sh
GO_VERSION=go1.25.0 ./go/build.sh
```

`GOTOOLCHAIN=auto` allows Go to download the version required by `go.mod`.
Use `GOTOOLCHAIN=local` to force the bundled version.

## Runtime checks

cgo is enabled, so the race detector works without extra setup:

```sh
go test -race ./...
```

Clang is available for Go's memory sanitizers:

```sh
CC=clang go test -msan ./...
CC=clang go test -asan ./...
```

Set `CGO_ENABLED=0` when building a pure-Go static binary. The race detector and
memory sanitizers require cgo.

Container caches are ephemeral. Mount volumes to retain them:

```sh
docker run --rm -it \
  -v "$PWD:/workspace" \
  -v go-mod-cache:/root/go/pkg/mod \
  -v go-build-cache:/root/.cache/go-build \
  codex-go
```
