# Security

## Incident: credential found in historical source (2026-07-29)

A hardcoded authentication token, with an embedded personal-data payload,
was discovered in `Assignment/Services/Remote/Constants.swift` while
auditing this repository for an architecture refactor. It had been present
since the repository's first commit and was already public.

Remediation:

- The active source file was removed; the affected constant was unused by
  the running app.
- Repository history was rewritten (via `git-filter-repo`) to replace the
  exposed value across every reachable branch, and the rewritten history was
  force-pushed to all four branches that carried it.
- A local secret scanner (`scripts/check-secrets.sh`) and a matching CI
  workflow (`.github/workflows/secret-scan.yml`) were added to catch this
  class of issue before it can be committed again.
- Rotating or revoking the underlying account/session that the credential
  belonged to is the account owner's responsibility and is handled outside
  of this repository.

**Limitation:** rewriting this repository's history cannot remove any copy
already taken by a clone, fork, cache, or third-party index prior to the
rewrite. Treat the original value as permanently compromised regardless of
its current validity.

## Reporting a vulnerability

This is a personal/educational reference project. If you find a security
issue, please open a private report via GitHub's "Report a vulnerability"
flow on this repository rather than a public issue.
