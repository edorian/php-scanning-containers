# Working in the scanning container

1. **Find the target and its instructions**
   - The host workspace is mounted at `/workspace`.
   - The target may be `/workspace` or one of its children.
   - Locate the checkout, then read its agent instructions.
   - For security work, read `SECURITY.md` when present and follow the project's
     private reporting process for unpublished findings.

2. **Match the work to the request**
   - For writing and exploration, stay within the scope the user requested.
   - When validating a security report, investigate the supplied claims and
     closely related code paths. Broaden the review when the evidence points to
     a shared or systemic cause.
   - When asked to find or scan for issues:
     - Scan the whole target unless the user gives a narrower scope.
     - Look for security vulnerabilities and significant correctness or
       reliability defects. Skip style-only observations unless asked for them.
     - Cover the relevant source, configuration, dependencies, entry points,
       and build, test, and CI paths.
     - Find and run the project's applicable checks. Account for failures in
       the result.

3. **When asked to find security issues, investigate thoroughly**
   - Build enough of a threat model to understand the system, its valuable
     assets, trust boundaries, entry points, and plausible attackers.
   - Review every meaningful attack surface, then follow promising paths deeply
     enough to establish how data and authority move through the system. Do not
     stop at the first plausible issue or after one pass through the code.
   - Use subagents when independent exploration, specialist analysis, or an
     adversarial second opinion would improve the review. Give them clear scopes
     and use fresh reviewers to challenge important candidate findings.
   - Take the time needed to reach convincing coverage. The lead agent must
     reconcile the work, remove duplicates, reject unsupported claims, and own
     the final severity and conclusions.

4. **Report scans and validations clearly**
   - Report confirmed findings first, ordered by severity. Include the affected
     location, impact, supporting evidence, and a practical fix direction.
   - Keep confirmed findings separate from ideas that could not be reproduced.
   - When `SECURITY.md` excludes confirmed behavior from security
     classification, put it under `Special cases` in the requested deliverable.
     Cite the policy and say whether the behavior remains an ordinary bug.
   - If there are no findings, say what you inspected and ran, along with any
     important gaps in coverage.

5. **Inspect project automation before running it**
   - Be careful before running project code.
   - Check build scripts, package hooks, test bootstraps, and CI hooks first.

6. **Use the container and workspace deliberately**
   - The container is disposable and gives you root access. Install tools and
     edit files as needed.
   - Anything that needs to survive the container must be stored under
     `/workspace`.
   - Keep source changes, tests, and fixtures in the target checkout. Use
     `/workspace/findings/` for other durable artifacts such as reports,
     proof-of-concept files, logs, and crash dumps.
   - Use `/tmp` only for disposable work.
   - Remove credentials, personal data, and production secrets from anything
     you save.

## Available tools

`gh`, `semgrep`, `jq`, `rg`, and `fd` are available. `gh` reads `GH_TOKEN`.
