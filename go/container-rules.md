# Go scanning container

Go analysis sandbox. Running as root with approvals disabled
(`claude --dangerously-skip-permissions`, `codex --yolo`), so run shell
commands, write files, and install packages freely.

## Layout

- `/workspace` — target codebase (host mount). Start here.
- `/usr/local/go` — Go toolchain. `/usr/local/go/src` is the full stdlib
  source; read it when runtime/stdlib behaviour is in question.
- `/root/go` — GOPATH; installed tools land in `/root/go/bin` (on PATH).
- `go`, `gofmt`, `gofumpt`, `goimports`, `staticcheck`, `golangci-lint`,
  `govulncheck`, `gosec`, `gopls`, `dlv`, `gotestsum`, `gh`, `semgrep`,
  `jq`, `rg`, `fd` — on PATH. `gh` auths from `$GH_TOKEN`.
- `GOTOOLCHAIN=auto`, so `go` downloads whatever toolchain the project's
  `go.mod` asks for. `go version` in `/workspace` is the truth, not the
  baked-in version.
- gcc and clang both present. `-race` works with the default gcc/cgo
  setup; `-msan` and `-asan` require `CC=clang`.

Output that should persist goes into /workspace

## Rules

1. Back every claim with a command you ran in the container. Prefer
   running things (`go build ./...`, `go vet ./...`, `go test ./...`,
   `gh …`) over static reasoning.
2. Bootstrap before analyzing: if `go.mod` exists, run `go mod download`
   (and `go mod tidy` only when you intend to change the module graph).
   For a vendored tree (`vendor/`), build with `-mod=vendor`.
3. Run tests with the race detector — `go test -race ./...` — whenever
   concurrency is anywhere near the change. A pass without `-race` says
   very little about a concurrent program.
4. If the package has fuzz targets (`func FuzzXxx(f *testing.F)`), run
   them: `go test -run '^$' -fuzz FuzzXxx -fuzztime 60s ./pkg`. Any new
   entry written to `testdata/fuzz/` is a reproducer — report it.
5. Install missing tools (apt, `go install`) without asking; mention in
   your reply what you added.
6. Before handing back a patch, discover the project's QA setup
   (`Makefile`, `Taskfile.yml`, `.golangci.yml`, `go.work`, CI configs)
   and run the checks that apply to the change. If the project pins its
   own linter config, use it rather than the image defaults. Fall back to
   `gofmt -l`, `go vet ./...`, `staticcheck ./...`, `govulncheck ./...`.
   Fix what they flag, or explain why not. Report results.
7. Build tags and GOOS/GOARCH hide code from a default build. When a file
   is behind a constraint, check it explicitly
   (`go build -tags integration ./...`, `GOOS=windows go vet ./...`)
   instead of assuming `./...` covered it.
