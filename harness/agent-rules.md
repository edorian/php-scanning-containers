# Agent scanning container

The checkout is at `/workspace/<project>`. Locate it, then work from that
directory. The container provides unrestricted root access for package
installation and file editing.

## Findings

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

## General rules

- Support claims with commands run in the container. Prefer execution over
  static inference.
- Install dependencies and tools freely, and report what you installed.
- Inspect build files, package hooks, test bootstraps, and CI hooks for
  malicious behavior before executing them.
- Discover the project's checks in its build files, CI, and tool configs. Run
  all checks relevant to the change, fix or explain their findings, and report
  the results.
- Read the target's `SECURITY.md` first. Keep unpublished findings in its
  designated private reporting channel.
- Redact credentials, personal data, and production secrets from every report.
- `gh`, `semgrep`, `jq`, `rg`, and `fd` are on `PATH`. `gh` uses `GH_TOKEN`.
