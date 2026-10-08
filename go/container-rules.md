## Go environment

- Go is installed at `/usr/local/go`; standard library source is in
  `/usr/local/go/src`.
- `/root/go` is `GOPATH`, and `/root/go/bin` is on `PATH`.
- `gofmt`, `gofumpt`, `goimports`, `staticcheck`, `golangci-lint`, `gosec`,
  `govulncheck`, `gopls`, `dlv`, and `gotestsum` are installed.
- `GOTOOLCHAIN=auto`; check `go version` inside the project before relying on a
  specific version.
- cgo, GCC, and Clang are available. Use GCC for `-race` and `CC=clang` for
  `-msan` or `-asan`.

## Go rules

- Prefer `go build`, `go vet`, and `go test` over static inference.
- Run `go mod download` when the project uses modules. Run `go mod tidy` only
  when changing the module graph. Respect vendoring with `-mod=vendor`.
- Use `go test -race ./...` for changes involving concurrency.
- Run relevant fuzz targets. Preserve and report any generated
  `testdata/fuzz` reproducer.
- Use the project's Makefile, task runner, CI, workspace, and linter config.
  Otherwise run the applicable subset of `gofmt -l`, `go vet ./...`,
  `staticcheck ./...`, and `govulncheck ./...`.
- Check every relevant build tag and `GOOS`/`GOARCH` target explicitly.
