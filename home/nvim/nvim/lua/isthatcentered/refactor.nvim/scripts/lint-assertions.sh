#!/usr/bin/env bash
set -euo pipefail

FORBIDDEN_PATTERNS=(
    'assert\.truthy'
    'assert\.is_true'
    'assert\.is_false'
    'assert\.falsy'
)

pattern=$(IFS='|'; echo "${FORBIDDEN_PATTERNS[*]}")
matches=$(grep -rn --include="*_spec.lua" -E "$pattern" lua/ 2>/dev/null || true)

if [[ -n "$matches" ]]; then
    echo "ERROR: Forbidden assertions found. Use assert.same() instead:"
    echo "$matches"
    exit 1
fi
