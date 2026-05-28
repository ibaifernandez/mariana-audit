#!/usr/bin/env bash
# Install graphify hooks (idempotent) + companion doc-sync hook.
#
# Run once after fresh clone. Safe to re-run — skips already-installed pieces.
#
# What it installs:
#   1. graphify post-commit + post-checkout hooks (via `graphify hook install`).
#      Auto-rebuilds the code graph on every commit. Reads `~/.graphify/...`.
#   2. Companion block appended to `.git/hooks/post-commit` that runs
#      `scripts/graphify-doc-sync.py` in background on every commit:
#         - re-extracts semantically changed docs/papers/images
#         - republishes the local graph to `~/.graphify/global-graph.json`
#         - graphify's own block stays untouched (managed by `graphify hook install`)
#
# Bypass: set `SKIP_HOOK_INSTALL=1` to no-op.
set -euo pipefail

if [ "${SKIP_HOOK_INSTALL:-}" = "1" ]; then
    echo "[install-hooks] SKIP_HOOK_INSTALL=1 — no-op"
    exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 1) graphify's own hook (manages its own markers; idempotent)
if command -v graphify >/dev/null 2>&1; then
    echo "[install-hooks] running graphify hook install..."
    graphify hook install || echo "[install-hooks] warning: graphify hook install returned non-zero"
else
    echo "[install-hooks] graphify CLI not on PATH — install with: uv tool install graphifyy"
fi

HOOK=".git/hooks/post-commit"
if [ ! -f "$HOOK" ]; then
    echo "[install-hooks] $HOOK missing — graphify hook install should have created it. Skipping companion."
    exit 0
fi

# 2) companion doc-sync block — append only if not present
if grep -q "graphify-doc-sync-start" "$HOOK"; then
    echo "[install-hooks] doc-sync companion block already present — skip"
else
    echo "[install-hooks] appending doc-sync companion block to $HOOK"
    cat >> "$HOOK" <<'BLOCK'

# graphify-doc-sync-start
# Companion hook (manual install via scripts/install-hooks.sh).
# Extends graphify's built-in code-only rebuild with semantic re-extraction
# when docs/papers/images change, plus auto-republish to the global graph.
# Runs detached so commit returns immediately.
if [ -x "$(git rev-parse --show-toplevel)/scripts/graphify-doc-sync.py" ]; then
    _DS_LOG="${HOME}/.cache/graphify-doc-sync.log"
    mkdir -p "$(dirname "$_DS_LOG")"
    nohup python3 "$(git rev-parse --show-toplevel)/scripts/graphify-doc-sync.py" >> "$_DS_LOG" 2>&1 < /dev/null &
    disown 2>/dev/null || true
fi
# graphify-doc-sync-end
BLOCK
fi

chmod +x scripts/graphify-doc-sync.py 2>/dev/null || true

echo "[install-hooks] done. Tail of $HOOK:"
tail -15 "$HOOK"
