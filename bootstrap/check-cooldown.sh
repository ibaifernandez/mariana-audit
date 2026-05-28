#!/usr/bin/env bash
# Mariana Audit — cooldown check.
#
# Determines whether running a fresh full audit is justified, based on:
#   1. Days since the last audit (if any).
#   2. Number of commits since the last audit.
#   3. File-change volume since the last audit (lines added/removed, not commits).
#
# Outputs a verdict on stdout (single line) plus a human-readable explanation
# on stderr. The verdict is one of:
#
#   FRESH           — no previous audit found; full audit warranted
#   RUN             — previous audit is stale OR significant changes since
#   PARTIAL         — moderate changes; recommend --dimensions instead of full
#   SKIP            — very recent audit + minor changes; suggest waiting
#
# Override: pass --force to ignore cooldown and always emit FRESH.
#
# Tunables (env vars):
#   COOLDOWN_HARD_DAYS=7         — minimum days before any re-audit even with changes
#   COOLDOWN_SOFT_DAYS=30        — days after which full audit is warranted regardless
#   COOLDOWN_COMMITS_FOR_PARTIAL=5   — commits threshold below which we say SKIP
#   COOLDOWN_COMMITS_FOR_FULL=30    — commits threshold above which we say RUN
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

if [ "${1:-}" = "--force" ]; then
    echo "FRESH"
    echo "[cooldown] --force passed; ignoring cooldown" >&2
    exit 0
fi

COOLDOWN_HARD_DAYS="${COOLDOWN_HARD_DAYS:-7}"
COOLDOWN_SOFT_DAYS="${COOLDOWN_SOFT_DAYS:-30}"
COOLDOWN_COMMITS_FOR_PARTIAL="${COOLDOWN_COMMITS_FOR_PARTIAL:-5}"
COOLDOWN_COMMITS_FOR_FULL="${COOLDOWN_COMMITS_FOR_FULL:-30}"

# Find latest audit dir matching docs/audits/YYYY-MM-DD-mariana/
LATEST_AUDIT_DIR="$(ls -d docs/audits/*-mariana 2>/dev/null | sort -r | head -1 || true)"

if [ -z "$LATEST_AUDIT_DIR" ]; then
    echo "FRESH"
    echo "[cooldown] No previous Mariana audit found in docs/audits/. Full audit warranted." >&2
    exit 0
fi

# Parse date from dir name. Format: docs/audits/YYYY-MM-DD-mariana
AUDIT_DATE="$(basename "$LATEST_AUDIT_DIR" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})-mariana$/\1/')"

if ! date -u -d "$AUDIT_DATE" >/dev/null 2>&1 && ! date -ju -f "%Y-%m-%d" "$AUDIT_DATE" >/dev/null 2>&1; then
    echo "FRESH"
    echo "[cooldown] Could not parse date from $LATEST_AUDIT_DIR; treating as fresh." >&2
    exit 0
fi

# Compute days since audit (cross-platform — try GNU first, then BSD/macOS)
AUDIT_EPOCH="$(date -u -d "$AUDIT_DATE" +%s 2>/dev/null || date -ju -f "%Y-%m-%d" "$AUDIT_DATE" +%s 2>/dev/null)"
NOW_EPOCH="$(date -u +%s)"
DAYS_SINCE=$(( (NOW_EPOCH - AUDIT_EPOCH) / 86400 ))

# Count commits since the audit date
COMMITS_SINCE="$(git log --since="$AUDIT_DATE 00:00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')"
# Lines changed since the audit date
LINES_CHANGED="$(git log --since="$AUDIT_DATE 00:00:00" --numstat --pretty=tformat: 2>/dev/null | awk '{ add+=$1; del+=$2 } END { print (add+del)+0 }')"

# Decision tree
emit() {
    local verdict="$1"
    local explanation="$2"
    echo "$verdict"
    echo "[cooldown] $explanation" >&2
}

# Case 1: hard floor — too recent regardless of activity
if [ "$DAYS_SINCE" -lt "$COOLDOWN_HARD_DAYS" ]; then
    if [ "$COMMITS_SINCE" -ge "$COOLDOWN_COMMITS_FOR_FULL" ]; then
        emit "RUN" \
            "Last audit ${DAYS_SINCE}d ago, but ${COMMITS_SINCE} commits since (≥ ${COOLDOWN_COMMITS_FOR_FULL}). Full re-audit justified."
        exit 0
    fi
    NEXT_DATE="$(date -u -d "$AUDIT_DATE +${COOLDOWN_HARD_DAYS} days" +%Y-%m-%d 2>/dev/null \
        || date -juv +"${COOLDOWN_HARD_DAYS}d" -f "%Y-%m-%d" "$AUDIT_DATE" +%Y-%m-%d 2>/dev/null \
        || echo "?")"
    emit "SKIP" \
        "Last audit only ${DAYS_SINCE}d ago (hard floor ${COOLDOWN_HARD_DAYS}d), with ${COMMITS_SINCE} commits / ${LINES_CHANGED} lines since. Suggested earliest next audit: ${NEXT_DATE}. Override with --force."
    exit 0
fi

# Case 2: soft ceiling — old enough that a full re-audit is always justified
if [ "$DAYS_SINCE" -ge "$COOLDOWN_SOFT_DAYS" ]; then
    emit "RUN" \
        "Last audit ${DAYS_SINCE}d ago (≥ soft ceiling ${COOLDOWN_SOFT_DAYS}d). Full re-audit warranted regardless of activity."
    exit 0
fi

# Case 3: between hard and soft — decide by commit activity
if [ "$COMMITS_SINCE" -ge "$COOLDOWN_COMMITS_FOR_FULL" ]; then
    emit "RUN" \
        "Last audit ${DAYS_SINCE}d ago with ${COMMITS_SINCE} commits since (≥ ${COOLDOWN_COMMITS_FOR_FULL}). Full re-audit justified."
elif [ "$COMMITS_SINCE" -ge "$COOLDOWN_COMMITS_FOR_PARTIAL" ]; then
    emit "PARTIAL" \
        "Last audit ${DAYS_SINCE}d ago with ${COMMITS_SINCE} commits / ${LINES_CHANGED} lines since. Recommend --dimensions to audit only the areas that changed."
else
    NEXT_DATE="$(date -u -d "$AUDIT_DATE +${COOLDOWN_SOFT_DAYS} days" +%Y-%m-%d 2>/dev/null \
        || date -juv +"${COOLDOWN_SOFT_DAYS}d" -f "%Y-%m-%d" "$AUDIT_DATE" +%Y-%m-%d 2>/dev/null \
        || echo "?")"
    emit "SKIP" \
        "Last audit ${DAYS_SINCE}d ago with only ${COMMITS_SINCE} commits since. Negligible delta; suggested next full audit: ${NEXT_DATE}. Override with --force or run with --dimensions for spot-check."
fi
