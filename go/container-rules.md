## Go environment

Go and its standard library source are installed under `/usr/local/go`.
`/root/go` is `GOPATH`, and `/root/go/bin` is on `PATH`.

The image includes cgo, GCC, Clang, Delve, `gofmt`, `gofumpt`, `goimports`,
`staticcheck`, `golangci-lint`, `gosec`, `govulncheck`, `gopls`, and `gotestsum`.
`CGO_ENABLED=1` and `GOTOOLCHAIN=auto`. The Go version requested by a module may
therefore be downloaded at runtime; confirm the effective version with
`go version`.

## Go rules

1. **Respect the module and toolchain setup**
   - Check `go.work`, `go.mod`, the `toolchain` directive, and `vendor/` before
     choosing commands.
   - Use `go mod download` when dependencies are needed.
   - Respect vendoring with `-mod=vendor`. Do not run `go mod tidy` or otherwise
     change the module graph unless the task requires it.

2. **Run a useful baseline**
   - Follow the project's Makefile, task runner, CI configuration, and lint
     configuration first.
   - When the project has no equivalent checks, run `go test ./...`,
     `go vet ./...`, `staticcheck ./...`, `govulncheck ./...`, and `gosec ./...`
     where they apply.
   - Confirm scanner results against the resolved module versions and a real
     path through the program before reporting them.

3. **Cover code hidden by the default build**
   - Inspect build tags, cgo files, and platform-specific filenames.
   - Test the affected tags and `GOOS`/`GOARCH` combinations instead of assuming
     that the default `./...` run covered them.

4. **Use the runtime tools for the bugs they can expose**
   - Run `go test -race ./...` for concurrent code. The race detector uses cgo
     and GCC in this image.
   - Use `CC=clang go test -msan ./...` or `CC=clang go test -asan ./...` for
     relevant cgo and native-memory investigations.
   - Run existing fuzz targets for parsers and other input-heavy code. Keep
     useful minimized corpus entries under `testdata/fuzz` in the checkout.
