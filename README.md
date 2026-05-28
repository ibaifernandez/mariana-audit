<div align="center">

# 🦑 mariana-audit

### The deepest code audit your project will ever get from an LLM.

Multi-dimensional, evidence-cited, severity-rubric'd audit of a software project — security, accessibility, UX, performance, SEO, database, architecture, legal compliance, ops, observability and documentation — driven by a knowledge graph of your codebase.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code Skill](https://img.shields.io/badge/Claude%20Code-Skill-D97757)](https://claude.ai/code)
[![Powered by graphify](https://img.shields.io/badge/Powered%20by-graphify-4F46E5)](https://github.com/safishamsi/graphify)
[![Validated in production](https://img.shields.io/badge/Validated-in%20production-22c55e)](#empirically-validated)

</div>

---

## 60-second pitch

You are shipping a product. You **think** it's solid. Then someone asks "is it secure? GDPR-compliant? WCAG-AA? Backed up? Documented?" and you stare at the ceiling.

This skill answers all of that — in one Claude Code session — with **citations**, **CVSS scores**, **regulation article references**, and (if you want) **automated mitigations** of any CRITICAL findings as they appear.

It is not a checklist. It is a discipline encoded as a skill, built from a real audit that surfaced an actively-exploitable XSS (CVSS 8.0) and a catastrophic backup gap in a production app — and mitigated both the same afternoon.

```bash
# In any repo onboarded to graphify
/mariana
```

That's it. The skill takes over.

---

## Table of contents

- [What you get](#what-you-get)
- [Quick start](#quick-start)
- [Modes](#modes)
- [What makes it different](#what-makes-it-different)
- [Architecture](#architecture)
- [Cooldown — won't waste your tokens](#cooldown--wont-waste-your-tokens)
- [Empirically validated](#empirically-validated)
- [Playbooks](#playbooks)
- [Severity rubrics](#severity-rubrics)
- [Honesty rules](#honesty-rules)
- [Installation](#installation)
- [Contributing](#contributing)
- [FAQ](#faq)
- [License](#license)

---

## What you get

After completion, the skill writes everything into a single dated directory in your repo:

```
docs/audits/2026-05-27-mariana/
├── REPORT.md           # full consolidated audit, ready to share
├── audit-A.md          # Fase A — Producto (a11y / UX / perf / SEO)
├── audit-B.md          # Fase B — Backend + Datos + Arquitectura
├── audit-C.md          # Fase C — Cumplimiento legal
├── audit-D.md          # Fase D — Ops + Mantenibilidad
├── findings.json       # machine-readable, queryable, every finding with full metadata
├── roadmap.md          # sprint-organized remediation plan (P0 / P1 / P2 / P3)
└── state.json          # resume state for `--resume`
```

Every finding includes:

| Field | Example |
|------|---------|
| Severity | `CRITICAL` (per published rubric, not opinion) |
| Severity metadata | `CVSS 3.1: 8.0 HIGH (AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:H/A:L), OWASP A03:2021` |
| Evidence | `server/routes/uploads.js:18` or `graphify query "..."` |
| Evidence source | `graph-local`, `graph-global`, `code-read`, `tool-external`, `manual-verification` |
| Remediation | playbook reference or external action required |
| Status | `OPEN`, `MITIGATED <sha>`, `NO VERIFICABLE — <reason>` |
| Cross-canon | "Same pattern previously caught in repo `<other-repo>` finding `<id>`" |

---

## Quick start

```bash
# 1. Install graphify (one time, machine-wide)
uv tool install graphifyy   # or: pipx install graphifyy

# 2. Install the skill (one time, machine-wide)
git clone https://github.com/ibaifernandez/mariana-audit ~/.claude/skills/mariana-audit

# 3. In any repo you want to audit
cd /path/to/your/repo
# Onboard + hooks + global publication, all idempotent:
bash ~/.claude/skills/mariana-audit/bootstrap/install.sh

# 4. Open Claude Code in the repo and trigger
/mariana
```

You will be asked which **mode** to run (see below). Confirm and the skill proceeds.

---

## Modes

| Mode | Behavior | When to use |
|------|----------|-------------|
| `report` *(default)* | Audit only. No fixes. Output: `REPORT.md` + `findings.json`. | First-ever audit, or when you want a planning artifact. |
| `mitigate` | Audit + **automatically** apply validated playbooks for any CRITICAL IMMEDIATE finding. Other severities go to report. | When you want production hardened the same session. |
| `case-by-case` | Audit + ask per finding `mitigate / report / skip`. | When you want full control of each touch. |

Plus useful flags:

- `--resume` — pick up from the last incomplete fase (e.g. after a token-window pause).
- `--dimensions A,B,D` — run only specific fases.
- `--no-cross-canon` — skip global-graph pattern inheritance (offline mode).
- `--force` — override cooldown.

---

## What makes it different

### 1. The graph is the foundation, not decoration

Most "AI code reviewers" `grep` files. This skill **queries a graph** of your code — god nodes, community cohesion, cross-file dependencies — and only falls back to raw-file reads when the graph doesn't surface the answer. Every finding tracks its `evidence_source` so you can measure the **graph leverage ratio** of your audit. Aim for >50%.

### 2. Cross-canon inheritance

If multiple repos are published to the same global graph (`~/.graphify/global-graph.json`), the skill **inherits patterns** across audits. Did the kanban repo's audit cazar a "Supabase Free without backups" pattern? Then auditing the next repo automatically inherits that hypothesis and verifies. **Each new audit is faster and cheaper than the last.**

### 3. Playbooks with battle-tested fixes

When the skill finds an XSS-via-SVG-upload (we caught one in production), it doesn't just report it — in `mitigate` mode it applies the **same fix that already worked in production**, with the **same regression tests**, and the **same commit-message template** that links back to the audit. Every playbook ships with: detection, exploit chain, multi-layer mitigation, regression tests, smoke test, commit-message template.

### 4. Calibrated severity, not vibes

No opinions. CVSS 3.1 for security. WCAG 2.1 levels for accessibility. Specific regulatory articles (GDPR, Ley 21.719 Chile, LGPD Brazil, CCPA) for legal findings. If you can't justify a severity per the rubric, it gets downgraded to INFO automatically.

### 5. Honesty as a first-class state

When the skill can't verify something from inside the audit (Core Web Vitals require a remote Lighthouse, vendor plan tier requires a dashboard login), it marks `[NO VERIFICABLE — <reason>]` instead of pretending. These items go to a dedicated section of the report for follow-up.

### 6. Cooldown gate — won't waste your tokens

Before doing anything, the skill checks when the last audit ran and how much has changed since. If you last audited 3 days ago and made 2 commits, you get **SKIP** with a suggested next-audit date. Override with `--force` only if you really want to.

---

## Architecture

```
~/.claude/skills/mariana-audit/
├── SKILL.md                       # the brain — what Claude reads first
├── README.md                      # this file
├── LICENSE                        # MIT
├── manifest.json                  # machine-readable skill metadata
├── bootstrap/
│   ├── install.sh                 # idempotent installer (graphify + hooks + onboard)
│   ├── check-cooldown.sh          # cooldown gate
│   ├── graphify-doc-sync.py       # vendored: doc-sync companion script
│   └── install-graphify-hooks.sh  # vendored: hook installer
├── playbooks/
│   ├── xss-svg-upload.md          # ✅ validated in production
│   └── supabase-free-backup-r2.md # ✅ validated in production
├── rubrics/
│   └── severity.md                # calibrated severity scales per dimension
└── templates/
    ├── REPORT.md.tpl              # consolidated report
    ├── findings.json.tpl          # machine-readable schema
    └── roadmap.md.tpl             # sprint-organized remediation plan
```

---

## Cooldown — won't waste your tokens

`bootstrap/check-cooldown.sh` emits one of four verdicts:

| Verdict | Trigger | Skill behavior |
|---------|---------|----------------|
| `FRESH` | No previous audit found | Proceed |
| `RUN` | Last audit ≥30 days ago, OR ≥30 commits since | Proceed |
| `PARTIAL` | Moderate activity (5–30 commits, 7–30 days) | Recommend `--dimensions` to audit only what changed |
| `SKIP` | Recent audit (<7 days) + <30 commits | STOP and suggest next-audit date |

Tunable via env vars:

- `COOLDOWN_HARD_DAYS=7` — minimum days before re-audit (default 7)
- `COOLDOWN_SOFT_DAYS=30` — days after which full audit is always justified (default 30)
- `COOLDOWN_COMMITS_FOR_PARTIAL=5` — below this, suggest skip
- `COOLDOWN_COMMITS_FOR_FULL=30` — above this, always RUN

Override entirely with `--force`.

---

## Empirically validated

This skill is not theoretical. Every protocol it enforces was developed during a real audit of a production Express + Supabase + React multi-tenant app over the course of a multi-day Claude Code session.

| Finding caught | CVSS / Severity | Mitigation playbook | Verified |
|----------------|------------------|---------------------|----------|
| Stored XSS via SVG upload (`/uploads/*` served same-origin without `fileFilter`, JWT exfil via `localStorage`) | 8.0 HIGH | [`xss-svg-upload.md`](playbooks/xss-svg-upload.md) | ✓ end-to-end smoke test + 5 regression tests |
| Supabase Free without daily backups / PITR (catastrophic operational risk) | CRITICAL operational | [`supabase-free-backup-r2.md`](playbooks/supabase-free-backup-r2.md) | ✓ daily cron live, restore drill green |

Plus 35+ additional findings across a11y, ops, legal, and architecture, all sitting in the audit report ready for sprint-based remediation.

The audit cost: 1 production-day of senior-engineer attention spread over ~5 hours of focused Claude Code time.

---

## Playbooks

Each playbook is a self-contained markdown with:

1. Detection (how to surface the finding)
2. Exploit chain or risk narrative
3. Multi-layer mitigation (defense in depth)
4. Regression test code
5. Smoke / verification steps
6. Commit-message template linking back to the audit

Currently shipped:

- **`xss-svg-upload.md`** — multer without `fileFilter` allowing SVG/HTML XSS. 4-layer fix: MIME allowlist + extension blocklist + magic-bytes validation (`file-type` library) + error handler.
- **`supabase-free-backup-r2.md`** — Supabase Free without daily backups. GitHub Actions nightly cron + `pg_dump` + Cloudflare R2 (Native API, not S3) with 30-day retention. Includes the **token-format gotcha** that took 7 incremental commits to land in production: `cfat_*` tokens work only with S3 API; `cfut_*` tokens work only with the Native API.

PRs adding new playbooks for CRITICAL patterns are very welcome.

---

## Severity rubrics

See [`rubrics/severity.md`](rubrics/severity.md). Summary:

- **Security:** CVSS 3.1 + OWASP 2021 category mandatory.
- **A11y:** WCAG 2.1 criterion + level (A/AA/AAA) mandatory.
- **Legal:** Regulation name + article reference mandatory. Covers GDPR (EU), Ley 21.719 (Chile), LGPD (Brazil), CCPA (California).
- **DB / Ops:** scaled by data-loss potential + recovery time.
- **Architecture:** god-node degree alone does NOT justify CRITICAL. **Read the code first.** Degree measures topology, not coupling.

Cross-cutting escalation rules add or remove a severity tier based on context (sensitive data, customer-facing surface, known regulatory deadlines, etc.).

---

## Honesty rules

The skill **refuses** to:

- Invent CVSS scores or WCAG criteria when uncertain.
- Mark "PASS" without an evidence cite.
- Skip the graphify prerequisite or cooldown gate.
- Apply a fix outside the safe-playbook list without explicit user OK.
- Mitigate in `--mode report`.

When something can't be verified from inside the audit, the skill marks `[NO VERIFICABLE — <reason>]` explicitly and lists it in the report as an external follow-up.

---

## Installation

### Per-machine (one time)

```bash
# Install graphify
uv tool install graphifyy
# or: pipx install graphifyy
# or: pip install --user graphifyy

# Install the skill
git clone https://github.com/ibaifernandez/mariana-audit ~/.claude/skills/mariana-audit
```

### Per-repo (one time, idempotent)

```bash
cd /path/to/your/repo
bash ~/.claude/skills/mariana-audit/bootstrap/install.sh
```

This onboards the repo to graphify, publishes it to the global graph, installs git hooks, and vendors the doc-sync companion script — all idempotent.

### Trigger the audit

In a Claude Code session opened in the repo:

```
/mariana
```

---

## Contributing

PRs welcome. Especially:

- **New playbooks** for CRITICAL patterns surfaced in real audits.
- **Rubric refinements** grounded in published standards.
- **Stack-specific scope adaptations** (e.g. Rails, Django, .NET).
- **Severity escalation rules** for industries with specific regulations (HIPAA, PCI-DSS, etc.).

Open an issue first if the change is large. Small playbook contributions can come directly via PR.

---

## FAQ

**Q: Does it work without graphify?**
A: No. The skill refuses to proceed without a knowledge graph because half the value (cross-canon inheritance, architecture surfacing via god-node detection) is gone. The installer onboards graphify automatically.

**Q: How much does an audit cost in tokens?**
A: For a medium repo (~150 files, ~500 graph nodes), a full audit consumes roughly 200k–400k input tokens + 30k–60k output tokens depending on remediation. Cross-canon inheritance reduces cost on subsequent audits.

**Q: Can I run it on a client's repo?**
A: Yes. The audit writes only to `docs/audits/<date>-mariana/` and any mitigation playbook files. Nothing else is touched. You always get a `git diff` before the skill commits anything.

**Q: How is this different from CodeQL / Semgrep / npm audit?**
A: Those are static analyzers tuned for one dimension (mostly security). This skill audits 13 dimensions including legal compliance and architecture. It uses graphify for context, plays well with those tools (results go in as `tool-external` evidence), and produces a roadmap, not just findings.

**Q: Will it leak proprietary code to Anthropic / others?**
A: The skill runs inside your Claude Code session. The same trust model as any Claude Code interaction applies. Nothing is sent to third-party services. graphify queries run against your local graph file; the `claude-cli` backend used by graphify itself routes through your existing Claude subscription auth (no separate API key, no separate data flow).

**Q: Can I run it on a PR diff instead of the whole repo?**
A: Not yet. Full-repo audits are the v1 use case. PR-scoped audits are on the roadmap.

---

## License

MIT — see [`LICENSE`](LICENSE).

---

## Acknowledgements

- [graphify](https://github.com/safishamsi/graphify) by Safi Shamsi — the knowledge-graph engine.
- The audit pattern that produced this skill was developed during a multi-day Claude Code session in May 2026, refining technique against the kanban-desk codebase.
- Built and maintained by [Ibai Fernández](https://ibaifernandez.com) at [AGLAYA](https://aglaya.biz).

---

## Related skills

- [`/graphify`](https://github.com/safishamsi/graphify) — knowledge-graph extraction (prerequisite).
- [`/dossier-fact-check`](https://github.com/ibaifernandez/dossier-fact-check) — fact-check public dossiers against the graph.

---

<div align="center">

**Found a bug or want a new playbook? [Open an issue](https://github.com/ibaifernandez/mariana-audit/issues).**

</div>
