#!/usr/bin/env bash
#
# Lightweight documentation-reference check for docs/Learning and other
# markdown docs: every relative markdown link must resolve to a real file,
# and every `CineConnect/...`/`CineConnectTests/...`/`CineConnectUITests/...`
# path mentioned in backticks must exist. Also matches the pre-Phase-9
# `Assignment...` prefix, so a doc that forgot to update a path reference
# after the rename gets caught (unless it's a marked historical mention -
# see the window check below). Not a full link/prose checker - just enough
# to catch "this doc points at a file that no longer exists."
#
# Usage: scripts/check-docs-links.sh

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail=0

echo "== Checking relative markdown links =="
while IFS=: read -r file line link; do
    [[ -z "$link" ]] && continue
    # Strip a trailing #anchor
    target="${link%%#*}"
    [[ -z "$target" ]] && continue
    dir="$(dirname "$file")"
    resolved="$dir/$target"
    if [[ ! -e "$resolved" ]]; then
        echo "BROKEN LINK: $file:$line -> $link (resolved: $resolved)"
        fail=1
    fi
done < <(grep -rnoE '\]\(([A-Za-z0-9_./-]+\.md)[^)]*\)' docs/ --include="*.md" 2>/dev/null \
    | sed -E 's/^([^:]+):([0-9]+):\]\(([^)]+)\)/\1:\2:\3/')

echo "== Checking backtick-quoted source paths mentioned in docs/Learning =="
echo "   (a path is only flagged if its line has no historical-context marker -"
echo "    removed/renamed/before/previous/deleted - since journal entries"
echo "    legitimately describe files that no longer exist under that name)"
while IFS=: read -r file line rest; do
    [[ -z "$rest" ]] && continue
    path="${rest#*\`}"
    path="${path%%\`*}"
    # Look at a small window around the match, not just the one line - a
    # "removed"/"renamed" explanation is often a sentence or two away.
    window_start=$(( line > 3 ? line - 3 : 1 ))
    window="$(sed -n "${window_start},$((line + 6))p" "$file")"
    if [[ ! -e "$path" ]]; then
        if echo "$window" | grep -qiE "removed|renamed|before|previous|deleted|→"; then
            continue
        fi
        echo "STALE PATH REFERENCE: $file:$line -> $path"
        fail=1
    fi
done < <(grep -rnoE '`((Assignment|CineConnect)[A-Za-z]*/[A-Za-z0-9_./-]+\.swift)`' docs/Learning --include="*.md" 2>/dev/null)

if [[ "$fail" -eq 1 ]]; then
    echo ""
    echo "check-docs-links: found broken references above."
    exit 1
fi

echo "check-docs-links: all checked links and source-path references resolve."
exit 0
