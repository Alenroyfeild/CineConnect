#!/usr/bin/env bash
#
# Lightweight secret scanner for CineConnect.
# Run locally before committing, or in CI on every push/PR.
#
# Usage:
#   scripts/check-secrets.sh              # scan all git-tracked files
#   scripts/check-secrets.sh --staged     # scan only staged changes (for a pre-commit hook)
#
# Exits non-zero if a likely secret is found. Prints only file:line and a
# redacted preview — never the full matched value.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

mode="${1:-}"
if [[ "$mode" == "--staged" ]]; then
    files=$(git diff --cached --name-only --diff-filter=ACM)
else
    files=$(git ls-files)
fi

if [[ -z "$files" ]]; then
    echo "check-secrets: no files to scan."
    exit 0
fi

# label:pattern pairs. Extend this list as new secret shapes are found.
patterns=(
    "JWT-like token:eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"
    "Authorization/Bearer header literal:(Authorization|Bearer)[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9._-]{10,}"
    "Hardcoded cookie value:[Cc]ookie[[:space:]]*[:=][[:space:]]*[\"'][^\"']{15,}"
    "Generic API key assignment:(api[_-]?key|apikey)[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9_-]{16,}"
    "Hardcoded password assignment:password[[:space:]]*[:=][[:space:]]*[\"'][^\"']{4,}"
    "PEM private key:BEGIN (RSA |EC |)PRIVATE KEY"
    "AWS access key:AKIA[0-9A-Z]{16}"
)

found=0
file_count=0

while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    file_count=$((file_count + 1))
    for entry in "${patterns[@]}"; do
        label="${entry%%:*}"
        pattern="${entry#*:}"
        matches=$(grep -nE "$pattern" "$file" 2>/dev/null || true)
        [[ -z "$matches" ]] && continue
        while IFS= read -r m; do
            [[ -z "$m" ]] && continue
            line="${m%%:*}"
            content="${m#*:}"
            preview=$(echo "$content" | tr -d '\n' | cut -c1-12)
            echo "POTENTIAL SECRET [$label] in $file:$line - \"${preview}...\" (redacted)"
            found=1
        done <<< "$matches"
    done
done <<< "$files"

if [[ "$found" -eq 1 ]]; then
    echo ""
    echo "check-secrets: potential secret(s) found above. Do not commit real values."
    echo "If this is a false positive, adjust scripts/check-secrets.sh patterns rather than bypassing the check."
    exit 1
fi

echo "check-secrets: no secrets found in ${file_count} file(s)."
exit 0
