---
name: mariana-audit
description: "Full-depth audit (a11y, UX, perf, SEO, security, DB, architecture, legal compliance, ops, observability) of a project. Powered by graphify (local + global knowledge graph). Reports findings with evidence and severity, optionally mitigates as discovered. Use when user says 'auditoría profunda', 'audit my repo', 'Mariana audit', 'Fosa de las Marianas', 'deep audit', or invokes /mariana."
trigger: /mariana
---

# /mariana — Mariana Trench Audit

Full-depth multi-dimensional audit of a codebase or product. Designed to surface **every defensible finding** across security, accessibility, UX, performance, SEO, database, architecture, legal compliance, ops, and documentation.

**Powered by graphify.** Without a knowledge graph the skill runs at half potency. The first thing it checks is graph presence and freshness.

**Empirically validated.** This skill is the codified outcome of an audit run in May 2026 against `aglaya-kanban-desk` (Express + Supabase + React stack) that surfaced 1 XSS (CVSS 8.0) and 1 backup-strategy CRITICAL in the first session, both mitigated the same day with verified end-to-end fixes.

## Usage

```
/mariana                       # audit current directory, ask mode interactively
/mariana <path>                # audit specific path
/mariana --mode report         # report-only, no fixes (default if unspecified)
/mariana --mode mitigate       # mitigate every CRITICAL IMMEDIATE as it appears (XSS, backup, etc.)
/mariana --mode case-by-case   # pause and ask per-finding whether to mitigate
/mariana --resume              # resume from last incomplete fase (reads audits/YYYY-MM-DD-mariana/state.json)
/mariana --no-cross-canon      # skip global graph cross-canon checks
/mariana --dimensions A,B,D    # run only specific fases (comma-separated)
```

## What you MUST do when invoked

### Step 0 — Mode + scope selection

If `--mode` not passed, ask user:

> Select audit mode:
>
> 1. **`report`** — audit only, no fixes. Output: `REPORT.md` + `findings.json`. Remediation in separate sessions.
> 2. **`mitigate`** — audit + **automatically** mitigate any CRITICAL IMMEDIATE finding using a validated playbook (XSS upload, backup strategy, etc.). Only CRITICAL — HIGH/MEDIUM/LOW stay in the report.
> 3. **`case-by-case`** — audit + for every CRITICAL/HIGH finding, pause and ask `mitigate / leave in report / skip`.

If `<path>` not given, use `.` (current directory).

### Step 1 — Prerequisite check + cooldown gate

Mariana audit relies on the knowledge graph and consumes meaningful tokens. Two gates run before any work begins.

#### 1a — Cooldown gate (avoid wasteful re-runs)

Run the cooldown script:

```bash
SKILL_DIR="$HOME/.claude/skills/mariana-audit"
VERDICT="$(bash "$SKILL_DIR/bootstrap/check-cooldown.sh" 2>/dev/null || echo FRESH)"
```

The verdict is one of:

- `FRESH` — no previous audit; proceed.
- `RUN` — previous audit is stale (>30 days) or significant activity since; proceed.
- `PARTIAL` — moderate activity; **recommend** the user pass `--dimensions <A,B,...>` to audit only what changed. Show the cooldown explanation and ask if they want to continue full or switch to partial.
- `SKIP` — very recent audit + negligible activity. **STOP** and show the user when the next audit is recommended. Ask if they want to override with `--force`.

If the user invoked `/mariana --force`, the cooldown is bypassed. Show the cooldown summary anyway for context.

The cooldown reads from `docs/audits/*-mariana/` directories. Without previous audits, it always returns `FRESH`.

#### 1b — Tooling prerequisites

Run the master installer (idempotent — safe even if everything is already in place):

```bash
SKILL_DIR="$HOME/.claude/skills/mariana-audit"
bash "$SKILL_DIR/bootstrap/install.sh"
```

This script:

1. Installs `graphify` CLI if missing (tries `uv` → `pipx` → `pip3 --user`).
2. Verifies Claude Code CLI is authenticated for headless extraction (`claude -p`).
3. Onboards the repo to graphify if no local graph exists (extracts + publishes to global).
4. Installs graphify's own git hooks (post-commit + post-checkout).
5. Installs the doc-sync companion hook (vendored from the skill) so every commit auto-republishes the graph to global.

If any step fails, the script reports what's missing and exits with non-zero. The skill should then surface the specific error and refuse to continue.

**Bypass envs (use sparingly):**

- `SKIP_INSTALL=1` — no-op the whole installer.
- `SKIP_ONBOARD=1` — skip onboarding (use existing graph).
- `SKIP_HOOKS=1` — skip hook installation.
- `MARIANA_TAG=<tag>` — override repo tag (default: directory name).
- `MARIANA_CONTINUE_WITHOUT_CLAUDE=1` — proceed even if Claude Code CLI is unauthenticated (audit will run with reduced power).

If the user accepts a degraded setup (stale graph, missing global publication, etc.), note the warning in the final `REPORT.md`.

### Step 2 — Phase 0: setup and scope matrix

Create output directory `docs/audits/YYYY-MM-DD-mariana/` (use today's UTC date).

Run scope detection. Map the project to detect stack archetype:

1. Run `graphify query "stack architecture entry point"` against the local graph.
2. Inspect for archetype indicators:
   - `package.json` → JS/TS frontend or Node backend
   - `pyproject.toml` / `requirements.txt` → Python
   - `Cargo.toml` → Rust
   - `go.mod` → Go
   - `index.html` at root + no backend → static site (vitrina)
   - `astro.config.*` → Astro static or hybrid
   - `next.config.*` → Next.js
   - `vite.config.*` + React/Vue → SPA
   - `Dockerfile` + `*.py` + FastAPI imports → Python backend
   - `*.sql` migrations + Supabase imports → Supabase Postgres
   - `.github/workflows/` → CI present
   - `Sentry`/`OpenTelemetry`/`pino` imports → observability layer
   - `helmet`/`express-rate-limit` → security middleware
   - `multer` → file upload (XSS-via-upload vector — flag for Phase B priority)

Build the scope matrix and report to user:

```
Stack detected: <archetype>
Dimensions in scope (mark N/A with reason):

#  Dim                       Applicable   Reason
1  Security                 YES / N/A   <reason>
2  Accessibility WCAG 2.1    YES / N/A   <reason>
3  Usability                YES / N/A   <reason>
4  Performance               YES / PARTIAL <reason — e.g., Core Web Vitals NOT VERIFIABLE without deploy>
5  Databases            YES / N/A   <reason>
6  Technical SEO               YES / N/A   <reason — auth-walled → mark partial: solo OG share tags>
7  Architecture + technical debt      YES
8  Legal compliance        YES / N/A   <reason — internal-only tool no third-party data>
9  Cookies + consent         YES / N/A   <reason>
10 Data retention + DPA      YES / N/A   <reason>
11 DevOps / CI               YES
12 Deployment + Observ.       YES / PARTIAL
13 Docs + maintainability     YES
```

**Archetype-specific defaults:**

- **Static vitrina** (HTML/Astro static, no backend): A pleno; B mínimo (no auth/DB); C cookies/privacy only if analytics; D docs only.
- **SaaS with backend + DB**: A→E full.
- **CLI / library**: B (deps, secrets); D (docs, tests, distribution). A and C usually N/A.
- **Public API without UI**: B + C full; A only perf/observability; D full.
- **Internal-only tool with auth-walled UI**: A full; B full; C reduced (no public privacy obligation, still internal compliance); D full.

Ask user `OK Phase 0` (or `--auto-ok` if non-interactive). Wait for confirmation.

### Step 3 — Phase A: Product surface

Dimensions: Accessibility (WCAG 2.1 AA), Usability, Performance, SEO.

**Use graphify first**, then read code raw only when graph doesn't surface the answer.

#### Accessibility (WCAG 2.1)

Required checks. Cite the WCAG criterion in each finding.

| Check | Method | WCAG ref |
|-------|--------|----------|
| Form labels associated (`htmlFor` / `aria-label` / `aria-labelledby` / wrapper) | `grep -c "<input\|<textarea\|<select"` vs `grep -c "htmlFor\|aria-label\|aria-labelledby"` | 1.3.1 + 3.3.2 + 4.1.2 |
| Modal dialog semantics (`role="dialog"` + `aria-modal`) | `grep "role=\"dialog\""` | 4.1.2 + 1.3.1 |
| Focus trap in modals + focus return on close | inspect modal components — look for `focus-trap-react` / `react-focus-lock` / manual trap | 2.4.3 + 2.4.11 |
| Skip-to-content link | `grep "skip"` in main entry HTML | 2.4.1 (Level A) |
| Heading hierarchy (single `<h1>` per page, no skips h1→h3) | inspect components | 1.3.1 |
| Live regions for notifications (`role="status"` / `aria-live`) | inspect notification components | 4.1.3 |
| Form validation accessible (`aria-invalid`, `aria-describedby`) | `grep "aria-invalid\|aria-describedby"` | 3.3.1 + 3.3.3 |
| Keyboard nav for drag-drop (look for `KeyboardSensor` if using `@dnd-kit`) | `grep "KeyboardSensor"` | 2.1.1 (Level A) |
| Icon-only buttons have accessible name | inspect button components | 4.1.2 |
| Touch targets ≥24×24 px | inspect CSS / Tailwind classes | 2.5.8 (WCAG 2.2 AA) |
| Color contrast 4.5:1 text / 3:1 UI | extract palette + compute ratio for top 5 pairs | 1.4.3 (Level AA) |
| `prefers-reduced-motion` honored | `grep "prefers-reduced-motion\|motion-reduce"` | 2.3.3 (Level AAA — flag as nice-to-have) |
| Empty states for collections (no boards, no results) | inspect list components | UX best practice |
| Mobile responsiveness — verify breakpoints | `grep -c "@media\|md:\|lg:"` and inspect viewport meta | 1.4.10 |

#### Usability

- Loading states present per async action (not just spinner global)
- Error states present per async action — no `alert()` / `confirm()` native (anti-pattern)
- Component density: report any single component >700 LOC as `densidad cognitiva` finding
- Form validation feedback: inline + accessible

#### Performance

- Bundle size: run `npm run build` or equivalent, report main bundle KB + gzip
- Code splitting: `React.lazy` per route, `manualChunks` vendor
- Core Web Vitals (LCP/INP/CLS): `[NOT VERIFIABLE — requires Lighthouse against deploy]` — recommend running PageSpeed Insights manually
- Server timing: middleware order in Express/FastAPI — heavy middleware before light = wasted CPU

#### SEO

If app is auth-walled → SEO ranking is N/A. Still check:
- `index.html`: `description`, OG tags (image, title, description), Twitter card, canonical, theme-color
- `robots.txt` present with explicit rules
- `sitemap.xml` if public pages exist

Output: `docs/audits/YYYY-MM-DD-mariana/audit-A.md` with table `ID|Dim|Finding|Evidence|Severity|Effort` and severity counts. Then wait for user `OK Phase A`.

### Step 4 — Phase B: Backend + Data + Architecture

**Highest density of findings. Where graphify shines.**

#### Security checklist

For each finding, mandatory fields: **OWASP Top 10 2021 category, CVSS 3.1 vector, attacker level, impact triad (C/I/A)**.

Required checks:

1. **Authentication & session**
   - Where is the session stored? JWT in localStorage = XSS-exfiltrable. HttpOnly cookie = better.
   - JWT TTL: > 24h without refresh token = HIGH (amplifies any XSS).
   - JWT claims (role, orgId, etc.) re-validated against DB per request? If not, stale role for entire token TTL.
   - JWT_SECRET handling: `grep -rE "JWT_SECRET\s*=\s*['\"]" --include="*.{js,ts,py}"` — never hardcoded.
   - `.env` files: `git log --all -- ".env"` — should be empty.
2. **Upload handling (CRITICAL — pattern caught in kanban audit)**
   - `multer` without `fileFilter`? Run `grep -A 10 "multer({" server/`. If `fileFilter` absent → CRITICAL.
   - Magic bytes validation post-upload? If not → CRITICAL.
   - SVG / HTML / JS uploads allowed by extension or MIME? → CRITICAL (XSS via SVG `<script>`).
   - See `playbooks/xss-svg-upload.md` for mitigation pattern.
3. **Authorization gates**
   - Endpoints behind `requireAuth`? Static `/uploads` typically NOT guarded (kanban pattern).
   - Role-based gates (`requireRole`, `requireWorkspaceMember`) consistently applied?
4. **Rate limiting**
   - Coverage: `/api/auth` is common; broader API often unprotected. HIGH if not global.
5. **CORS**
   - Production allowlist explicit (not `*` nor `*.netlify.app` wide).
6. **Webhook security**
   - HMAC signature validation present?
   - Idempotency claim (e.g. `claim_webhook_event`) to block replay?
   - IP allowlist for known senders (Lemon Squeezy, Cal.com, etc.)?
7. **Headers**
   - `Helmet` active for API.
   - CSP / X-Frame / X-Content-Type / Permissions-Policy / HSTS in HTML response (Netlify `_headers` or `netlify.toml`).
8. **SSRF / Path traversal**
   - HTTP redirects: `follow_redirects=True`? Check final URL is verified per hop.
   - File read by path: parameterized, denylist `..`.
9. **Information disclosure**
   - Default platform URLs exposed (e.g. `*.railway.app`, `*.vercel.app`)?
     - If yes → HIGH. Block via Cloudflare WAF or middleware that requires proxy header.
10. **Dependencies**
    - Run `npm audit --omit=dev --audit-level=high` (Node) or `pip-audit` (Python). Report HIGH+ CVEs.

#### Database checklist

1. **RLS** (Row Level Security) per table — if Supabase or Postgres with Supabase pattern, RLS must be ON even if `service_role` is used (defense in depth).
2. **Indexes** likely missing on frequent query columns. Run `EXPLAIN ANALYZE` on top 10 queries via the graph or backend logs.
3. **Foreign key constraints** complete.
4. **Backup strategy documented** — provider (Supabase / RDS / managed Postgres) plan with PITR? If Supabase **Free** → **CRITICAL OPERATIONAL** (no daily backups, no PITR).
   - See `playbooks/supabase-free-backup-r2.md` for mitigation.
5. **Migrations** versioned, idempotent, runnable in CI.
6. **GRANTs** explicit for `anon` / `authenticated` roles where appropriate. Without explicit GRANT, future client-side queries via `supabase-js` fail.
7. **PII inventory** in schema: identify which columns contain personal data (email, name, IP, device_id, etc.). Feed into Phase C RAT.

#### Architecture + technical debt

This is where **graphify is irreplaceable**. Required queries:

```bash
# God nodes (top connected — potential bottlenecks)
graphify query "god nodes top connected" --budget 1500
# Then for each god node, inspect with:
graphify explain "<node_name>"

# Community cohesion: low cohesion + high size = candidates for refactor
graphify query "communities low cohesion high size" --budget 1000

# Cross-file dependencies that bridge communities (architectural debt)
graphify query "surprising connections cross community" --budget 1000
```

**Critical lesson from kanban audit:** god-node `degree` measures **surface of imports**, not **business logic acoupling**. A thin router that delegates 5 endpoints to 5 services will have `degree=29` and look like a hub but actually be well-factored. **Read the code** before recommending refactor.

#### Cross-canon check (if global graph available)

For each finding, query global graph for pattern matches:

```bash
# Did this kind of issue already get caught in another repo?
graphify query "<finding-keyword>" --graph ~/.graphify/global-graph.json --budget 500
```

If a known pattern matches (e.g. "Supabase Free without backup" was previously caught in another repo), include reference: `pattern previously caught in <other-repo> as <finding-id>`. Reuses prior analysis.

Output: `audit-B.md`. Wait for `OK Phase B`.

### Step 5 — Phase C: Legal compliance

**Cite the specific article** of the regulation each finding violates.

Regulations to consider:
- **GDPR** (EU): Articles 5 (principles), 6 (lawfulness), 7 (consent), 13/14 (info to data subject), 15 (access), 16 (rectification), 17 (erasure), 18 (restriction), 20 (portability), 25 (privacy by design), 28 (processor obligations), 30 (RAT), 32 (security), 33 (breach notification), 35 (DPIA).
- **Ley 21.719** (Chile): principles (finalidad, proporcionalidad, calidad, responsabilidad, seguridad, transparencia, confidencialidad), Art. 9 (consent), Art. 14 ter (info al titular), Chap. V (international transfers).
- **LGPD** (Brazil): Art. 7 (legal basis), Art. 18 (data subject rights), Art. 39 (DPO).
- **CCPA / CPRA** (California): notice at collection, right to delete, opt-out of sale/sharing.

Required checks:

1. **Privacy policy** — does a public privacy policy exist for **this specific product**? Many sites have a single org-wide policy that doesn't enumerate sub-products. If not → CRITICAL (Art. 13/14 GDPR + 14 ter Ley 21.719).
2. **Processor declaration** — is every processor (Supabase, Resend, Railway, Cloudflare, Netlify, GitHub Actions, OpenAI, Anthropic, Mailchimp, Cal.com, etc.) named in the policy? Each unnamed = CRITICAL.
3. **DPA registry** — does `docs/legal/` exist? Are signed DPAs / DPA acceptances logged? If `docs/legal/` doesn't exist → CRITICAL.
4. **Self-delete endpoint** (Art. 17 GDPR / Art. 18 LGPD / Art. 18 CCPA) — `grep -rn "DELETE.*account\|DELETE.*user" server/`. If absent → CRITICAL.
5. **Self-export endpoint** (Art. 20 GDPR portability) — `grep -rn "export.*user\|download.*data" server/`. If absent → CRITICAL.
6. **Legal basis** documented per processing activity (Art. 6 GDPR).
7. **TOMs** (Art. 32 GDPR — Technical and Organizational Measures) documented in `docs/legal/TOMs.md`.
8. **Breach notification procedure** (Art. 33 — 72h timeline) — runbook present?
9. **DPIA** (Art. 35) — required if processing sensitive data, large-scale monitoring, automated decisions with legal effects.
10. **Cookie / consent banner** — required if app loads analytics, fingerprinting, or non-essential cookies. Auth tokens in localStorage are NOT cookies (no banner needed for those alone).
11. **Retention policy** — explicit retention period per data category (cards, comments, attachments, audit logs).
12. **International transfers** (GDPR Chap. V / Ley 21.719 Chap. V) — every US-based processor (Supabase US, OpenAI US, Resend US, etc.) requires SCC or other transfer mechanism documented.
13. **DPO contact** — public contact (email or form) dedicated for data protection inquiries.
14. **JWT minimization** — JWTs should not carry PII beyond what's strictly necessary (don't put full email, name, phone in claims if a user ID is enough).

Output: `audit-C.md`. Wait for `OK Phase C`.

### Step 6 — Phase D: Ops + Maintainability

1. **CI/CD** — `.github/workflows/` or equivalent present? At minimum: test + build + lint on PR.
2. **Error tracking** — Sentry, Rollbar, Bugsnag, etc. integrated? Server + client.
3. **Structured logs** — JSON logs vs free-form? Goes where (stdout to Railway logs, vs proper aggregator)?
4. **Uptime monitoring** — UptimeRobot, BetterStack, Pingdom? Configured?
5. **Alerts** — backup failure, queue depth, error rate spike, deploy failure?
6. **Runbooks** — `docs/runbooks/` for incidents (DB restore, deploy rollback, secret rotation, etc.).
7. **README / AGENTS.md / CLAUDE.md** — match reality? Use the graph: are these files **hub nodes** (referenced by many) or **orphans** (linked to nothing)?
8. **ADRs** — Architecture Decision Records present? Major decisions documented?
9. **Linter + formatter + types** — ESLint, Prettier, TypeScript, mypy, ruff, etc. Configured? Enforced in CI?
10. **Dependency hygiene** — when was `npm update` / `pip-compile --upgrade` last run? Dependabot enabled?
11. **Onboarding** — `docs/onboarding/` or equivalent for new contributors.
12. **Deploy strategy** — git-push triggered? Manual? Approval gate? Rollback procedure?

Output: `audit-D.md`. Wait for `OK Phase D`.

### Step 7 — Phase E: Synthesis + Roadmap

Consolidate all findings from A→D into:

1. **Priority matrix** — for every finding:
   ```
   ID | Sev | Effort (h) | Impact | Priority | Sprint
   ```
   - P0: CRITICAL + legal exposure
   - P1: HIGH security/UX bloqueante
   - P2: MEDIUM
   - P3: LOW / nice-to-have

2. **Roadmap** in 2-week sprints:
   - Sprint 1: close all P0
   - Sprint 2: close all P1
   - Sprint 3-N: P2/P3 según bandwidth

3. **Executive summary** (5 bullets max):
   - Overall health (green/amber/red, with reason)
   - Legal exposure (high/med/low + articles in play)
   - Top 3 highest-ROI actions
   - Risk if nothing done in 3 months
   - External resources needed (legal review, pentest, professional a11y audit)

4. **Outputs**:
   - `docs/audits/YYYY-MM-DD-mariana/REPORT.md` — full audit consolidated
   - `docs/audits/YYYY-MM-DD-mariana/findings.json` — queryable, all findings with full metadata
   - `docs/audits/YYYY-MM-DD-mariana/roadmap.md` — sprint-organized remediation plan
   - `docs/audits/YYYY-MM-DD-mariana/state.json` — completion state (for `--resume`)

5. **Commit**:
   ```
   docs(audit): mariana-trench full audit — N findings (P0:n P1:n P2:n P3:n)
   ```

If user is in `--mode mitigate` or `--mode case-by-case`, ALL CRITICAL IMMEDIATE findings will have been mitigated DURING the audit (see Protocol below). The audit then records `MITIGATED` status + remediation commit SHA for each.

## Protocol — CRITICAL IMMEDIATE

If during any fase a finding meets **CRITICAL IMMEDIATE** criteria (actively exploitable, regulatory non-compliance with quick fix, or operational catastrophic risk like missing backups), the protocol activates:

1. **Pause the audit** immediately.
2. **Report the finding** with full details (CVSS, vector, PoC concept if security).
3. **Based on mode**:
   - `report`: log, ask user to mitigate later, **do NOT proceed until user explicitly says continue**.
   - `mitigate`: apply the matching playbook from `playbooks/`. If no playbook exists for this finding, ask user to confirm before manual mitigation.
   - `case-by-case`: ask user `mitigate / leave / skip`. Wait for answer.
4. After mitigation, **verify the fix**: smoke test, unit test, end-to-end check against production if applicable.
5. **Commit the fix** with clear message referencing audit ID:
   ```
   fix(security): block SVG/HTML uploads (XSS via /uploads/*, CVSS 8.0)

   Found during audit docs/audits/2026-05-27-mariana/audit-B.md:B-CRIT-01.
   Mitigation playbook: ~/.claude/skills/mariana-audit/playbooks/xss-svg-upload.md.
   ...
   ```
6. **Update the audit doc** marking the finding as `MITIGATED` with SHA reference.
7. **Resume the audit** from the paused fase.

### Built-in CRITICAL IMMEDIATE playbooks

Located in `playbooks/`. Each is a self-contained markdown with: detection, exploit chain, mitigation (4-layer where applicable), tests, verification, commit message template.

- `xss-svg-upload.md` — multer without `fileFilter` accepting SVG/HTML. Patched with MIME allowlist + extension blocklist + magic-bytes validation.
- `supabase-free-backup-r2.md` — Supabase Free plan without PITR/daily backups. GitHub Actions cron + `pg_dump` + Cloudflare R2 native API. Includes restore smoke test.
- More to add as audits surface new patterns.

## Severity rubrics

See `rubrics/severity.md` for the calibrated scale.

Summary:

- **Security**: CVSS 3.1 score. 9.0+ = CRITICAL, 7.0–8.9 = HIGH, 4.0–6.9 = MEDIUM, 0.1–3.9 = LOW. Plus OWASP category.
- **A11y**: WCAG 2.1 Level A/AA failures = CRITICAL/HIGH. Level AAA = MEDIUM/LOW.
- **Legal**: per-article weighting. Art. 5 (principles), 13/14 (info to subject), 17 (erasure), 32 (security), 33 (breach) — if any violated outright → CRITICAL.
- **DB / Ops**: operational catastrophic risk (data loss without backup) → CRITICAL operational. Otherwise scaled by recovery time.
- **Architecture**: refactor cost vs maintenance burden. Cohesion + degree + complexity ciclomática.

## Honesty rules

1. **No fixes without OK in `report` mode.** Even cosmetic.
2. **Never invent a CVSS or WCAG ref.** If unsure, mark `[NOT VERIFIABLE — cite needed]`.
3. **`[NOT VERIFIABLE]`** is a valid finding state. Mark explicitly when:
   - Core Web Vitals require Lighthouse against deploy (skill can't run remote Lighthouse from CLI).
   - Cyclomatic complexity per-function requires `eslint-plugin-complexity` or `radon` not installed.
   - DPA acceptance state requires logging into vendor dashboards.
   - Plan tier (Supabase Free vs Pro) requires dashboard login.
4. **Evidence cite is mandatory**: every finding has `evidence` field with `file:line` or `graphify-query`. Without cite → finding gets rejected by review.
5. **Severity is calibrated, not opinionated**. Use the rubric. If you can't justify severity per rubric, the finding may be informational.
6. **Cross-canon checks** flag pattern matches but do NOT auto-inherit severity. Verify on this repo.

## Evidence source tracking

Every finding in `findings.json` MUST carry `evidence_source`:

- `graph-local` — detected via graphify query/explain/path on local graph, no raw-code read.
- `graph-global` — pattern inherited from another repo in `~/.graphify/global-graph.json`.
- `code-read` — read directly from source file.
- `tool-external` — `npm audit`, `pip-audit`, Lighthouse, etc.
- `manual-verification` — human confirmed (e.g. dashboard access).

Aim for **majority `graph-local` / `graph-global`**. If <50% → the graph is being underused; revisit query strategies.

## When to refuse

- If no `graphify-out/graph.json` exists and user refuses to onboard first → refuse. Mariana without graph = half-blind audit. Suggest `/graphify` first.
- If user requests `--mode mitigate` for a finding that's outside the safe-playbook list (e.g. "refactor entire auth layer") → refuse the automation; flag finding for sprint dedicated.
- If user asks to skip the prerequisite check ("just run the audit") → refuse. The prerequisite is the foundation.
- If output dir `docs/audits/YYYY-MM-DD-mariana/` already exists from today → ask `--resume` instead of overwriting.

## When the skill is overkill

If the user only wants ONE dimension audited (e.g. "just check security"), suggest `--dimensions B` and skip the others. Don't run the full skill for one dimension — it's wasteful.

If the user is in a tiny repo (<50 files, no backend, no users) → recommend a lighter heuristic check instead of the full Mariana protocol.

## Resuming

`--resume` reads `docs/audits/YYYY-MM-DD-mariana/state.json` and continues from the last incomplete fase. State.json schema:

```json
{
  "started_at": "2026-05-27T15:30:00Z",
  "mode": "mitigate",
  "fase_completed": ["0", "A"],
  "fase_in_progress": "B",
  "findings_count_by_fase": { "A": 24 },
  "critical_mitigated": [
    { "id": "B-CRIT-01", "sha": "402b0d7", "playbook": "xss-svg-upload" }
  ]
}
```

State is saved after each fase. On resume, the skill picks up from `fase_in_progress`.

## Acknowledgements

This skill encodes practice from a real audit against `aglaya-kanban-desk` (May 2026), commits `dad39d8` (refactor), `402b0d7` (XSS fix), `5e94b54` (Phase C close).

Powered by [graphify](https://github.com/safishamsi/graphify).

Licensed MIT. See `LICENSE`.
