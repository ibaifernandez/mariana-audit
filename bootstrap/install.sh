#!/usr/bin/env bash
# Mariana Audit — full installer for the target repo.
#
# Run from inside the repo you want to audit. Idempotent — safe to re-run.
#
# What it does (in order, each step idempotent):
#   1. Verifies / installs graphify CLI (via uv tool > pip > pipx fallback).
#   2. Verifies / configures Claude Code CLI for headless extraction.
#   3. Onboards the repo to graphify (extract local graph + publish to global)
#      if not already onboarded.
#   4. Installs graphify's own git hooks (post-commit + post-checkout).
#   5. Installs the doc-sync companion hook (vendored graphify-doc-sync.py)
#      for automatic semantic-on-docs re-extraction + global republish.
#
# Bypass:
#   SKIP_INSTALL=1            — no-op the whole script.
#   SKIP_ONBOARD=1            — skip step 3 (extract).
#   SKIP_HOOKS=1              — skip steps 4-5.
#   MARIANA_TAG=<tag>         — override repo tag for global graph (default: dir name).
set -euo pipefail

if [ "${SKIP_INSTALL:-}" = "1" ]; then
    echo "[mariana-install] SKIP_INSTALL=1 — no-op"
    exit 0
fi

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

SKILL_DIR="${MARIANA_SKILL_DIR:-$HOME/.claude/skills/mariana-audit}"
TAG="${MARIANA_TAG:-$(basename "$ROOT_DIR")}"

echo "[mariana-install] target repo:    $ROOT_DIR"
echo "[mariana-install] global tag:     $TAG"
echo "[mariana-install] skill dir:      $SKILL_DIR"
echo

# ─── Step 1 — graphify CLI ────────────────────────────────────────────
echo "[mariana-install] Step 1: graphify CLI"

if command -v graphify >/dev/null 2>&1; then
    GRAPHIFY_VERSION="$(graphify --version 2>/dev/null | head -1)"
    echo "  ✓ graphify present: $GRAPHIFY_VERSION"
else
    echo "  → graphify not found; attempting install..."
    if command -v uv >/dev/null 2>&1; then
        echo "  → using uv tool install"
        uv tool install graphifyy
    elif command -v pipx >/dev/null 2>&1; then
        echo "  → using pipx install"
        pipx install graphifyy
    elif command -v pip3 >/dev/null 2>&1; then
        echo "  → using pip3 install --user"
        pip3 install --user graphifyy
    else
        echo "  ✗ no installer found (uv, pipx, pip3). Install one of them first." >&2
        echo "  → uv recommended: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
        exit 1
    fi
    if ! command -v graphify >/dev/null 2>&1; then
        echo "  ✗ graphify install succeeded but binary not on PATH." >&2
        echo "  → add the installer's bin dir to PATH (e.g. ~/.local/bin, ~/.cargo/bin, or uv tool bin)." >&2
        exit 1
    fi
    echo "  ✓ graphify installed: $(graphify --version 2>/dev/null | head -1)"
fi

# ─── Step 2 — Claude Code CLI for headless backend ────────────────────
echo
echo "[mariana-install] Step 2: Claude Code CLI"

if command -v claude >/dev/null 2>&1; then
    if claude -p "say pong, nothing else" --output-format json 2>/dev/null | grep -q '"result"\s*:\s*"pong"'; then
        echo "  ✓ claude CLI authenticated"
    else
        echo "  ⚠ claude CLI present but not authenticated"
        echo "  → run \`claude /login\` in another terminal and re-run this installer"
        if [ "${MARIANA_CONTINUE_WITHOUT_CLAUDE:-}" != "1" ]; then
            exit 1
        fi
    fi
else
    echo "  ⚠ claude CLI not found"
    echo "  → install from https://claude.ai/code (or skip with MARIANA_CONTINUE_WITHOUT_CLAUDE=1)"
    if [ "${MARIANA_CONTINUE_WITHOUT_CLAUDE:-}" != "1" ]; then
        exit 1
    fi
fi

# ─── Step 3 — Onboard repo to graphify ────────────────────────────────
echo
echo "[mariana-install] Step 3: onboard repo to graphify"

if [ "${SKIP_ONBOARD:-}" = "1" ]; then
    echo "  → SKIP_ONBOARD=1, skipping"
elif [ -f graphify-out/graph.json ]; then
    NODE_COUNT="$(python3 -c "import json; print(len(json.load(open('graphify-out/graph.json'))['nodes']))" 2>/dev/null || echo "?")"
    echo "  ✓ local graph exists ($NODE_COUNT nodes)"
else
    echo "  → no local graph; extracting (this can take 5-30 minutes for medium repos)..."
    if [ ! -f .graphifyignore ]; then
        cat > .graphifyignore <<'EOF'
# graphify ignore — exclude noise, force-include relevant gitignored content
.claude/
data/
node_modules/
dist/
build/
.venv/
__pycache__/
*.pyc
*.lock
*.sqlite
*.sqlite-*
tmp/
cache/
playwright-report/
test-results/
coverage/
EOF
        echo "  → created .graphifyignore with defaults"
    fi
    graphify extract . --backend claude-cli --max-concurrency 4 --global --as "$TAG"
fi

# Always (re)publish to global to ensure the tag is fresh
if [ -f graphify-out/graph.json ]; then
    if ! graphify global list 2>/dev/null | grep -q "  $TAG:"; then
        echo "  → publishing to global graph as '$TAG'"
        graphify global add graphify-out/graph.json --as "$TAG"
    else
        echo "  ✓ already published to global as '$TAG'"
    fi
fi

# ─── Step 4 — graphify's own git hooks ────────────────────────────────
echo
echo "[mariana-install] Step 4: graphify post-commit hook"

if [ "${SKIP_HOOKS:-}" = "1" ]; then
    echo "  → SKIP_HOOKS=1, skipping"
elif [ -f .git/hooks/post-commit ] && grep -q "graphify-hook-start" .git/hooks/post-commit; then
    echo "  ✓ graphify hook already installed"
else
    graphify hook install
fi

# ─── Step 5 — doc-sync companion hook ─────────────────────────────────
echo
echo "[mariana-install] Step 5: doc-sync companion hook"

if [ "${SKIP_HOOKS:-}" = "1" ]; then
    echo "  → SKIP_HOOKS=1, skipping"
else
    # Vendor the doc-sync script into the repo so the hook can call it
    mkdir -p scripts
    if [ ! -f scripts/graphify-doc-sync.py ]; then
        if [ -f "$SKILL_DIR/bootstrap/graphify-doc-sync.py" ]; then
            cp "$SKILL_DIR/bootstrap/graphify-doc-sync.py" scripts/graphify-doc-sync.py
            chmod +x scripts/graphify-doc-sync.py
            echo "  ✓ vendored scripts/graphify-doc-sync.py"
        else
            echo "  ⚠ skill bootstrap script not found at $SKILL_DIR/bootstrap/graphify-doc-sync.py"
        fi
    else
        echo "  ✓ scripts/graphify-doc-sync.py already present"
    fi

    # Append companion hook block if missing
    HOOK=".git/hooks/post-commit"
    if [ -f "$HOOK" ] && grep -q "graphify-doc-sync-start" "$HOOK"; then
        echo "  ✓ doc-sync companion block already present"
    elif [ -f "$HOOK" ]; then
        cat >> "$HOOK" <<'BLOCK'

# graphify-doc-sync-start
# Companion hook installed by mariana-audit skill.
# Extends graphify's built-in code-only rebuild with semantic re-extraction
# on doc/image changes, plus auto-republish to the global graph.
if [ -x "$(git rev-parse --show-toplevel)/scripts/graphify-doc-sync.py" ]; then
    _DS_LOG="${HOME}/.cache/graphify-doc-sync.log"
    mkdir -p "$(dirname "$_DS_LOG")"
    nohup python3 "$(git rev-parse --show-toplevel)/scripts/graphify-doc-sync.py" >> "$_DS_LOG" 2>&1 < /dev/null &
    disown 2>/dev/null || true
fi
# graphify-doc-sync-end
BLOCK
        echo "  ✓ appended doc-sync companion block to $HOOK"
    fi
fi

# ─── Done ─────────────────────────────────────────────────────────────
echo
echo "[mariana-install] ✓ done — '$TAG' is ready for /mariana audit"
echo "[mariana-install]   try: graphify global list"
echo "[mariana-install]   then in a Claude Code session: /mariana"
