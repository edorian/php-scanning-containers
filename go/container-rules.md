# Go scanning container

The checkout is at `/workspace/<project>`. Locate it, then work from that
directory. The container provides unrestricted root access for package
installation and file editing.

Keep every persistent result in the findings:

- Maintain `/workspace/findings.md` as the complete report. Create it at the
  start, update it as evidence develops, and record the scope and checks when
  there are no findings.
- When validating reports, include a `Special cases` section. Record every
  confirmed behavior excluded from security classification by the target's
  `SECURITY.md`, cite the applicable policy, explain the exclusion, and state
  whether it remains an ordinary bug. Keep policy exclusions distinct from
  disproved or unreproduced claims.
- Put optional PoCs, inputs, or large supporting output in
  `/workspace/findings/` when they do not fit reasonably in the report.
- Put files in the checkout when they are intended source changes, tests, or
  fixtures.
- Use `/tmp` for disposable work. Summarize useful results in `findings.md` or
  move supporting files into `findings/` before finishing.

## Environment

- Go is installed at `/usr/local/go`; standard library source is in
  `/usr/local/go/src`.
- `/root/go` is `GOPATH`, and `/root/go/bin` is on `PATH`.
- `gofmt`, `gofumpt`, `goimports`, `staticcheck`, `golangci-lint`, `gosec`,
  `govulncheck`, `gopls`, `dlv`, `gotestsum`, `gh`, `semgrep`, `jq`, `rg`, and
  `fd` are installed. `gh` uses `GH_TOKEN`.
- `GOTOOLCHAIN=auto`; check `go version` inside the project before relying on a
  specific version.
- cgo, GCC, and Clang are available. Use GCC for `-race` and `CC=clang` for
  `-msan` or `-asan`.

## Rules

- Support claims with commands run in the container. Prefer `go build`,
   `go vet`, and `go test` over static inference.
- Run `go mod download` when the project uses modules. Run `go mod tidy` only
   when changing the module graph. Respect vendoring with `-mod=vendor`.
- Use `go test -race ./...` for changes involving concurrency.
- Run relevant fuzz targets. Preserve and report any generated
   `testdata/fuzz` reproducer.
- Install required tools and report what you installed.
- Use the project's Makefile, task runner, CI, workspace, and linter config.
   Otherwise run the applicable subset of `gofmt -l`, `go vet ./...`,
   `staticcheck ./...`, and `govulncheck ./...`. Fix findings or explain them,
   and report all results.
- Check every relevant build tag and `GOOS`/`GOARCH` target explicitly.
