# Mariana Audit Report — sample-app

**Audit ID:** `sample-app-2026-05-27-mariana`
**Mode:** `mitigate`
**Started:** 2026-05-27 15:30 UTC
**Finished:** 2026-05-28 11:00 UTC (across two Claude Code sessions)
**Repo commit at start:** `e5e7e3d` (sanitized)
**Repo commit at end:** `5e94b54` (sanitized)
**Auditor:** `mariana-audit` skill v1.0.0 (Powered by graphify)

> *This is a sanitized example audit, included with the skill so prospective users can see what an output looks like. All domain names, SHAs, paths and metric values have been altered or generalized. The structure, severity counts, and decision rationale match a real audit run against a production Express + Supabase + React multi-tenant app in May 2026.*

---

## Executive summary

- **Overall health:** 🟡 amber — solid engineering foundation with two CRITICAL findings mitigated during the audit; 19 non-critical findings remain on the roadmap.
- **Legal exposure:** medium — public app lacks a dedicated privacy policy; 5 CRITICAL regulatory findings under GDPR Art. 13/14, 17, 20, 28 + Ley 21.719 Art. 14 ter.
- **Top-3 highest-ROI actions:**
  1. Accept DPAs in vendor dashboards (Supabase, Resend, Netlify, Cloudflare, GitHub Actions) — 1.5h human time.
  2. Draft + publish dedicated privacy policy for this product — 4-6h drafting + ~€500-1500 legal review.
  3. Implement self-delete + self-export endpoints (GDPR Art. 17 + 20) — ~1 day code.
- **Risk if nothing done in 3 months:** regulatory exposure compounds. Any data subject request triggers GDPR Art. 12 obligations within 30 days; without endpoints + policy, requests cannot be served compliantly.
- **External resources needed:** legal counsel for privacy policy review (€500-1500); accessibility expert review (€1000-3000) to validate the 8 critical a11y findings; Supabase Pro upgrade ($25/mo) to retire the custom backup workflow.

---

## Finding counts by severity

| Severity | Count |
|----------|-------|
| CRÍTICO mitigated during audit | 2 |
| CRÍTICO open | 5 |
| ALTO     | 16 |
| MEDIO    | 13 |
| BAJO     | 5 |
| INFO / N-A | 3 |
| [NO VERIFICABLE] | 4 |
| **Total findings** | **48** |

---

## Scope confirmation

Stack archetype detected: **SaaS with Express backend + Supabase Postgres + React frontend + multi-tenant** → all dimensions in scope at full depth.

| # | Dimension | Applicable | Reason / Notes |
|---|-----------|------------|----------------|
| 1 | Seguridad | SÍ | auth user-facing, JWT, file uploads, webhooks |
| 2 | Accesibilidad WCAG 2.1 | SÍ | UI used daily by team and external clients |
| 3 | Usabilidad | SÍ | herramienta de trabajo diario |
| 4 | Performance | PARCIAL | bundle verifiable; Core Web Vitals NO VERIFICABLE (require Lighthouse against deploy with auth session) |
| 5 | Bases de datos | SÍ | Supabase Postgres with RLS, multi-tenant data |
| 6 | SEO técnico | PARCIAL | auth-walled; only OG share tags + robots.txt apply |
| 7 | Arquitectura + deuda | SÍ | grafo onboardado, cross-canon checks habilitados |
| 8 | Cumplimiento legal | SÍ | datos personales + integraciones third-party + procesamiento internacional |
| 9 | Cookies + consent | SÍ | JWT en localStorage no requiere banner (no es cookie de tracking); pero analytics si está activo, sí |
| 10 | Data retention + DPA | SÍ | 5 procesadores externos, ninguno con DPA documentado en repo |
| 11 | DevOps / CI | SÍ | un workflow GitHub Actions presente (cron); ningún CI de tests/build/lint |
| 12 | Despliegue + observabilidad | PARCIAL | logs a stdout via PaaS; Sentry/alerts NO VERIFICABLE sin dashboard access |
| 13 | Docs + mantenibilidad | SÍ | docs/ con 14 archivos, ADRs hasta 025 |

---

## Fase A — Producto cara al usuario

**Findings count:** 24 (CRÍTICO: 8, ALTO: 8, MEDIO: 5, BAJO: 1, INFO: 2)

### Top critical findings

| ID | Hallazgo | Evidencia | WCAG criterion | Severidad |
|----|----------|-----------|----------------|-----------|
| A-01 | Form labels not programmatically associated (52 inputs, 0 `htmlFor`, 0 `aria-label`) | `client/src/components/*` | 1.3.1 + 3.3.2 + 4.1.2 (A) | CRÍTICO |
| A-02 | Drag-and-drop without keyboard support (0 `KeyboardSensor`) | `client/src/components/Board/*` | 2.1.1 (A) | CRÍTICO |
| A-03 | Modal dialogs lack `role="dialog"` + `aria-modal` | `client/src/components/*Modal*` | 4.1.2 + 1.3.1 (A) | CRÍTICO |
| A-04 | Icon-only buttons lack accessible name | `client/src/components/*` | 4.1.2 (A) | CRÍTICO |
| A-05 | Spinner lacks `role="status"` + `aria-live` | `client/src/components/UI/Spinner.jsx` | 4.1.3 (A) | CRÍTICO |
| A-17 | Focus trap absent in 6+ modals (no library, no manual) | grafo: 6 modal components matched | 2.4.3 + 2.4.11 (AA) | CRÍTICO |
| A-19 | Skip-to-content link absent | `client/index.html` | 2.4.1 (A) | CRÍTICO |
| A-22 | Forms lack `aria-invalid` / `aria-describedby` / `aria-required` (35 setError vs 0 ARIA) | grep `setError` vs `aria-` | 3.3.1 + 3.3.3 (A) | CRÍTICO |

### Performance highlights

- Bundle: **721 KB JS / 205 KB gzip / 1815 modules / 1 chunk** — login screen ships the entire app. Recommended fix: `React.lazy` per route + `manualChunks` for vendor.
- Core Web Vitals: **[NO VERIFICABLE]** — require Lighthouse against authenticated production session. Recommendation: run PageSpeed Insights manually post-login.

### SEO

- App is auth-walled → SEO ranking is N/A.
- `index.html` lacks OG tags, Twitter card, canonical → sharing in social/Slack degrades preview (A-12 MEDIO).
- `robots.txt` present but boilerplate; no `sitemap.xml`.

Per-finding detail in `audit-A.md`.

---

## Fase B — Backend + Datos + Arquitectura

**Findings count:** 20 (1 CRÍTICO mitigated, 1 CRÍTICO mitigated, 9 ALTO, 6 MEDIO, 2 BAJO, 1 INFO)

### Clean verifications (positive findings)

✓ Zero `dangerouslySetInnerHTML` in client
✓ Zero SQL injection vectors (Supabase JS parameterized)
✓ `JWT_SECRET` never hardcoded in production code
✓ `.env` never committed in git history
✓ Service role key never exposed to client
✓ Production CORS scoped to custom domain
✓ Helmet active on API responses
✓ Path traversal mitigated in `deleteFile`
✓ HSTS `max-age=31536000` on API

### CRITICAL findings (mitigated in-flight)

| ID | Hallazgo | Evidencia | OWASP / CVSS | Severidad | Estado |
|----|----------|-----------|--------------|-----------|--------|
| B-CRIT-01 | XSS via SVG upload (multer without fileFilter + `/uploads/*` served same-origin) | `server/routes/uploads.js:18`, `server/app.js:77`, `netlify.toml /uploads/* redirect` | A03:2021 + CVSS 3.1: 8.0 HIGH (AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:H/A:L) | CRÍTICO | **MITIGATED `aaaa111`** via playbook `xss-svg-upload.md` |
| B-CRIT-02 | Supabase plan = Free → no daily backups / PITR → catastrophic data-loss risk | manual-verification: operator confirmed Free plan | OWASP A05 (operational) + RTO/RPO undefined | CRÍTICO operational | **MITIGATED `bbbb222`** via playbook `supabase-free-backup-r2.md` (daily pg_dump → Cloudflare R2 Native API, 30d retention) |

### HIGH findings (open)

| ID | Hallazgo | Severidad | Notes |
|----|----------|-----------|-------|
| B-02 | JWT 7d TTL without refresh-token rotation — amplifies any XSS to 7-day session compromise | ALTO | Playbook `jwt-long-ttl-no-refresh.md` available; refactor of significant scope. P1 sprint. |
| B-03 | Default platform URL `web-production-xxx.up.railway.app` publicly accessible — info disclosure + WAF bypass | ALTO | Playbook `railway-url-exposed.md` available; quick fix via Express middleware. P1. |
| B-04 / B-11 | RLS not enabled on `organizations` / `boards` (latent; mitigated by service_role server-side today) | ALTO | Defense-in-depth gap. P1. |
| B-05 | HTML responses lack CSP / X-Frame / X-Content-Type / Referrer-Policy headers | ALTO | Playbook `csp-headers-missing.md` available; netlify.toml block. P1, ~30min. |
| B-06 | Rate limit only on `/api/auth` — broader API endpoints + internal route unprotected | ALTO | Extend to all endpoints. P1. |
| B-07 | JWT claims (role / orgId) not re-validated against DB per request — stale role for 7 days | ALTO | Middleware re-validation. P1. |
| B-10 | Deadline 2026-10-30: GRANTs obligatorios — no CI enforcement | ALTO (degrades over time) | GitHub Actions workflow lint. P2 (>5 months out). |

### Architecture findings

God nodes top-5 from local graph:

| Rank | Node | Degree | Reading |
|------|------|--------|---------|
| 1 | `digestRouter` | 29 | Surface of imports, not coupling. Router delegates 5 endpoints to services. **No refactor warranted.** |
| 2 | `supabaseAdmin` | 20 | Central DB client. Expected. |
| 3 | `api` (HTTP client) | 19 | UI mostly imports directly; opportunity for domain hooks (P2). |
| 4 | `useEscapeKey()` | 18 | Reused hook. Healthy. |
| 5 | `WorkspaceMembers()` | 12 | Single component. Healthy. |

Per-finding detail in `audit-B.md`.

---

## Fase C — Cumplimiento legal

**Findings count:** 18 (CRÍTICO: 5, ALTO: 7, MEDIO: 4, BAJO: 2)

### Positive findings

✓ Org-wide privacy policy exists at https://<org-site>/privacy (trilingual ES/EN/PT-BR, declares responsible, processors for the org domain, retention periods).
✓ CORS production allowlist explicit and scoped.

### CRITICAL findings

| ID | Hallazgo | Regulation / Article | Subjects affected | Severidad |
|----|----------|----------------------|--------------------|-----------|
| C-01 | This specific product lacks a dedicated privacy policy (org-wide policy does not enumerate this sub-product) | GDPR Art. 13 + 14, Ley 21.719 Art. 14 ter | EU + Chile + all | CRÍTICO |
| C-02 | Supabase is NOT declared as a processor in the org-wide policy (it processes all sensitive data) | GDPR Art. 13 + 28 | EU + all | CRÍTICO |
| C-03 | `docs/legal/` directory does not exist — no DPAs archived, no RAT, no TOMs documentation | GDPR Art. 28 + 30 + 32, LGPD Art. 39 | all | CRÍTICO |
| C-04 | No endpoint to self-delete account / data | GDPR Art. 17, LGPD Art. 18, CCPA right-to-delete | all | CRÍTICO |
| C-05 | No endpoint to self-export data | GDPR Art. 20 (data portability) | EU + analogous in other jurisdictions | CRÍTICO |

### Operational legal items (require human action)

- **DPAs to accept in vendor dashboards** (1.5h human time):
  - Supabase
  - Resend
  - Railway / hosting platform
  - Cloudflare
  - Netlify
  - GitHub Actions
- **Privacy policy drafting + legal review:** estimated €500-1500 + 4-6h drafting.
- **DPO contact decision:** who, how published (mailto / form on privacy page).

---

## Fase D — Ops + Mantenibilidad

**Findings count:** 8 (CRÍTICO: 0, ALTO: 4, MEDIO: 3, BAJO: 1)

| ID | Hallazgo | Severidad |
|----|----------|-----------|
| D-01 | No CI workflow for tests/build/lint on PRs (only the cron exists) | ALTO |
| D-02 | No error tracking (Sentry / equivalent) integrated | ALTO |
| D-03 | No uptime monitoring configured | ALTO |
| D-04 | No alerts on backup-workflow failure (post-mitigation) | ALTO |
| D-05 | No structured logs (free-form to stdout) | MEDIO |
| D-06 | No ESLint / Prettier / TypeScript configured | MEDIO |
| D-07 | README out of sync with `package.json` version | MEDIO |
| D-08 | `docs/runbooks/` exists for backup-restore but lacks deploy-rollback | BAJO |

---

## Mitigations applied during this audit

| Finding | Playbook used | SHA | Verified |
|---------|---------------|-----|----------|
| B-CRIT-01 XSS via SVG upload | `xss-svg-upload.md` | `aaaa111` | ✓ smoke test + 5 regression tests + prod redeploy verified |
| B-CRIT-02 Supabase backup | `supabase-free-backup-r2.md` | `bbbb222` (workflow scaffold) → `cccc333` (final) | ✓ 1st run green + restore drill verde + 10/10 tables validated |

---

## NO VERIFICABLE items

| ID | Description | Why not verifiable | Recommended external action |
|----|-------------|--------------------|-----------------------------|
| A-NV-01 | Core Web Vitals (LCP / INP / CLS) for production | Requires Lighthouse against authenticated session | Run PageSpeed Insights manually post-login + log results in `docs/perf/<date>.md` |
| A-NV-02 | Color contrast across all UI surfaces | Manual sampling shows 2 pairs failing AA 4.5:1; full audit requires axe-core or Stark | Run axe-core + Stark in dev tools |
| B-NV-01 | Cyclomatic complexity per function | `eslint-plugin-complexity` not installed | Install + run + report top-10 |
| D-NV-01 | Sentry / uptime / alert state | Requires dashboard login on respective providers | Operator to confirm in writing |

---

## Priority matrix (excerpt — full list in roadmap.md)

| Finding | Severidad | Effort (h) | Impacto | Prioridad |
|---------|-----------|-----------|---------|-----------|
| C-01 dedicated privacy policy | CRÍTICO | 6 + legal review | regulatory | P0 |
| C-04 self-delete endpoint | CRÍTICO | 6 | regulatory | P0 |
| C-05 self-export endpoint | CRÍTICO | 6 | regulatory | P0 |
| C-03 docs/legal/ scaffold | CRÍTICO | 1 | regulatory | P0 |
| C-02 declare Supabase processor (depends on C-01) | CRÍTICO | 0.5 | regulatory | P0 |
| B-05 CSP headers | ALTO | 0.5 | security | P1 |
| B-03 Railway URL block | ALTO | 1 | security | P1 |
| B-06 rate limit global | ALTO | 2 | security | P1 |
| B-02 JWT refresh | ALTO | 6 | security | P1 |
| B-07 JWT claims revalidation | ALTO | 3 | security | P1 |
| A-01 form labels | CRÍTICO | 4 | a11y | P1 |
| A-02 drag-drop keyboard | CRÍTICO | 8 | a11y | P1 |
| A-17 focus trap | CRÍTICO | 4 | a11y | P1 |
| A-22 form aria | CRÍTICO | 4 | a11y | P1 |
| D-02 Sentry integration | ALTO | 2 | ops | P1 |

Full priority list in `roadmap.md`.

---

## Graphify usage statistics

| Source | Findings | % of total |
|--------|----------|-----------|
| `graph-local` (`graphify query/explain`) | 23 | 48% |
| `graph-global` (cross-canon pattern) | 4 | 8% |
| `code-read` (raw file inspection) | 16 | 33% |
| `tool-external` (`npm audit`, etc.) | 2 | 4% |
| `manual-verification` (dashboard / runtime) | 3 | 6% |

**Graph leverage ratio: 56%.** Above the 50% target; room to improve cross-canon queries on subsequent audits.

---

## Cross-canon inheritance used

| Current finding | Pattern from | Original audit |
|-----------------|--------------|----------------|
| B-CRIT-02 Supabase Free no backup | repo `<another-tag>` finding `B-CRIT-02` | 2026-04-15 |
| B-03 Railway URL exposed | repo `<another-tag>` finding `B-03` | 2026-04-15 |
| C-02 Supabase processor not declared | repo `<another-tag>` finding `C-02` | 2026-04-15 |
| C-03 docs/legal/ absent | repo `<another-tag>` finding `C-03` | 2026-04-15 |

---

## External resources to budget

| Type | Description | Estimated cost |
|------|-------------|----------------|
| Legal | Privacy policy drafting + review | €500-1500 one-time |
| Service upgrade | Supabase Pro for PITR (retires custom backup workflow) | $25/mo recurring |
| Tooling | axe-core + Stark for full a11y verification | Free (devtools extensions) |
| Audit | Professional a11y audit (WebAIM / Deque) | €1000-3000 one-time |
| Audit | Penetration test (when scaling) | €3000-8000 one-time |

Total external budget recommended: ~€2000-5000 one-time + $25/mo recurring.

---

## Conclusions

The audited app has solid engineering foundations: zero hardcoded secrets, parametrized queries, helmet middleware, scoped CORS, deliberate architectural choices (Rules first / LLM second pattern noted in another project — applied as guideline here too). Two CRITICAL findings of different categories — a security exploit and an operational catastrophic risk — were both surfaced and mitigated in-flight during the audit session, with verified end-to-end fixes.

The remaining work is concentrated in three buckets:

1. **Accessibility (24 findings, 8 CRITICAL, all WCAG Level A).** This needs a dedicated 2-week sprint or a professional a11y audit. The findings are concrete and actionable — semantic HTML for forms, focus traps in modals, keyboard sensors for drag-drop, ARIA roles for live regions.

2. **Legal compliance (18 findings, 5 CRITICAL).** Mostly documentary: a dedicated privacy policy, DPA acceptances (1.5h human time), self-delete + self-export endpoints (1 day code), `docs/legal/` scaffold (30 min). Total estimated effort: ~2 weeks + €500-1500 legal review.

3. **Security hardening beyond the two mitigated CRITICALs (8 HIGH).** Mostly quick wins: CSP headers (30 min), Railway URL block (1h), global rate limit (2h). Plus one refactor of meaningful scope: JWT refresh-token rotation (6h + careful migration).

If all three buckets are addressed in the next 4 weeks, the product moves from amber to green on overall health and from medium to low on legal exposure.

---

*Generated by `/mariana` skill. Powered by graphify. Licensed MIT.*

*This is a sanitized example. See https://github.com/ibaifernandez/mariana-audit for the skill that produces audits like this one.*
