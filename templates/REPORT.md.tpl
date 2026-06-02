# Mariana Audit Report — <REPO_NAME>

**Audit ID:** `<repo>-YYYY-MM-DD-mariana`
**Mode:** `report | mitigate | case-by-case`
**Started:** YYYY-MM-DD HH:MM UTC
**Finished:** YYYY-MM-DD HH:MM UTC
**Repo commit at start:** `<sha>`
**Repo commit at end:** `<sha>`
**Auditor:** `mariana-audit` skill v2 (Powered by graphify)

---

## Evidence integrity snapshot

| Evidence tier | Findings | % |
|---------------|----------|---|
| PROVEN (file:line or tool output) | <n> | <pct>% |
| SUSPECTED (graph-derived, unverified in code) | <n> | <pct>% |
| UNVERIFIABLE (requires external access/runtime) | <n> | <pct>% |
| **Total** | **<n>** | 100% |

**Graph leverage ratio:** `(graph-local + graph-global) / total findings` = <pct>%. Target ≥ 50%.

Source breakdown: `code-read` <n> · `graph-local` <n> · `graph-global` <n> · `tool-external` <n> · `manual-verification` <n>

---

## Regression delta _(omit section if no previous audit exists)_

Previous audit: `<repo>-YYYY-MM-DD-mariana`

| Status | Count | Finding IDs |
|--------|-------|-------------|
| NEW | <n> | <IDs> |
| FIXED | <n> | <IDs> |
| REGRESSED ⚠️ | <n> | <IDs — always P0> |
| ESCALATED | <n> | <IDs> |
| DEESCALATED | <n> | <IDs> |
| UNCHANGED | <n> | — |

Any `REGRESSED` finding is automatically **P0** regardless of severity. A fix that didn't hold is a process failure.

---

## Executive summary

- **Overall health:** 🟢 green / 🟡 amber / 🔴 red — <one-line justification>
- **Legal exposure:** high / medium / low — <articles in play>
- **Top-3 highest-ROI actions:** <bullets>
- **Risk if nothing done in 3 months:** <short narrative>
- **External resources needed:** <legal review / pentest / a11y audit / service tier upgrade>

---

## Finding counts by severity

| Severity | Count |
|----------|-------|
| CRITICAL mitigated during audit | <n> |
| CRITICAL open | <n> |
| HIGH | <n> |
| MEDIUM | <n> |
| LOW | <n> |
| INFO / N-A | <n> |
| UNVERIFIABLE | <n> |
| **Total findings** | **<n>** |

---

## Scope confirmation

| # | Dimension | Applicable | Reason / Notes |
|---|-----------|------------|----------------|
| 1 | Security | YES / N/A | |
| 2 | Accessibility WCAG 2.1 | YES / N/A | |
| 3 | Usability | YES / N/A | |
| 4 | Performance | YES / PARTIAL | CWV NOT VERIFIABLE (NV_RUNTIME) without Lighthouse against deploy |
| 5 | Databases | YES / N/A | |
| 6 | Technical SEO | YES / N/A | |
| 7 | Architecture + debt | YES | |
| 8 | Legal compliance | YES / N/A | |
| 9 | Cookies + consent | YES / N/A | |
| 10 | Data retention + DPA | YES / N/A | |
| 11 | DevOps / CI | YES | |
| 12 | Deployment + observability | YES / PARTIAL | |
| 13 | Docs + maintainability | YES | |

---

## Phase A — Product surface

**Findings count:** <n> (CRITICAL: <n>, HIGH: <n>, MEDIUM: <n>, LOW: <n>)
**Confidence:** PROVEN <n> · SUSPECTED <n> · UNVERIFIABLE <n>

Per-finding detail in `audit-A.md`. Top critical highlighted below.

### Top critical findings

| ID | Confidence | Finding | Evidence | WCAG / norm | Severity |
|----|------------|---------|----------|-------------|----------|
| A-XX | PROVEN | <title> | `<file:line>` | `<criterion>` | CRITICAL |

---

## Phase B — Backend + Data + Architecture

**Findings count:** <n> (CRITICAL: <n>, HIGH: <n>, MEDIUM: <n>, LOW: <n>)
**Confidence:** PROVEN <n> · SUSPECTED <n> · UNVERIFIABLE <n>

Per-finding detail in `audit-B.md`.

### Clean verifications (positive findings — no issue)

✓ <verification 1>
✓ <verification 2>

### Top critical findings (security + DB)

| ID | Confidence | Finding | Evidence | OWASP / CVSS | Severity | Status |
|----|------------|---------|----------|--------------|----------|--------|
| B-CRIT-XX | PROVEN | <title> | `<file:line>` | `<OWASP / CVSS>` | CRITICAL | MITIGATED `<sha>` / OPEN |

### Architecture findings

- God nodes top-5 with reading of `degree` + cohesion + community.
- Cross-canon patterns inherited (if global graph available).

---

## Phase C — Legal compliance

**Findings count:** <n> (CRITICAL: <n>, HIGH: <n>, MEDIUM: <n>, LOW: <n>)
**Confidence:** PROVEN <n> · SUSPECTED <n> · UNVERIFIABLE <n>

Per-finding detail in `audit-C.md`.

### Positive findings (compliance already in place)

✓ <e.g. privacy policy exists trilingual>
✓ <e.g. CORS allowlist explicit production-scoped>

### Critical findings (regulatory)

| ID | Confidence | Finding | Reg / Art. | Subjects affected | Severity |
|----|------------|---------|------------|--------------------|----------|
| C-XX | PROVEN | <title> | `<Reg. Art.>` | <all / EU / etc.> | CRITICAL |

### Operational legal items (require human action)

- DPAs to accept in vendor dashboards: <list>
- Privacy policy draft + review: estimated €<n>
- DPO contact decision (who, how published): pending

---

## Phase D — Ops + Maintainability

**Findings count:** <n>
**Confidence:** PROVEN <n> · SUSPECTED <n> · UNVERIFIABLE <n>

Per-finding detail in `audit-D.md`.

### Top critical findings

| ID | Confidence | Finding | Evidence | Severity |
|----|------------|---------|----------|----------|

---

## Mitigations applied during this audit (mode `mitigate` or `case-by-case`)

| Finding | Playbook used | SHA | Verified |
|---------|---------------|-----|----------|
| B-CRIT-01 XSS | `xss-svg-upload.md` | `<sha>` | ✓ |
| B-CRIT-02 backup | `supabase-free-backup-r2.md` | `<sha>` | ✓ |

---

## UNVERIFIABLE items

Items that could not be verified from inside the audit. Each requires external action.

| ID | Subtype | Description | Why not verifiable | Recommended external action |
|----|---------|-------------|--------------------|-----------------------------|
| <ID> | NV_RUNTIME / NV_DASHBOARD / NV_CREDENTIALS / NV_TOOL | <desc> | <reason> | <action> |

---

## Priority matrix

P0 = close in Sprint 1 (CRITICAL + legal exposure + any REGRESSED)
P1 = HIGH Sprint 2 (4 weeks)
P2 = MEDIUM Sprint 3+
P3 = LOW / nice-to-have backlog

| Finding | Confidence | Severity | Effort (h) | Impact | Priority | Regression |
|---------|------------|----------|-----------|--------|----------|------------|
| <ID> | PROVEN | <sev> | <h> | <user / business / regulatory> | <P0-P3> | NEW / REGRESSED / etc. |

Full priority list in `roadmap.md`.

---

## Graphify usage statistics

| Source | Findings | % of total |
|--------|----------|-----------|
| `graph-local` (`graphify query/explain`) | <n> | <pct>% |
| `graph-global` (cross-canon pattern) | <n> | <pct>% |
| `code-read` (raw file inspection) | <n> | <pct>% |
| `tool-external` (`npm audit`, etc.) | <n> | <pct>% |
| `manual-verification` (dashboard / runtime) | <n> | <pct>% |

**Graph leverage ratio:** `(graph-local + graph-global) / total` = <pct>%.

If <50%, the graph is underused. Future audits should improve query coverage.

---

## Cross-canon inheritance used

| Current finding | Inherited confidence | Verified to | Pattern from | Original audit |
|-----------------|---------------------|-------------|--------------|----------------|
| <ID> | SUSPECTED | PROVEN / SUSPECTED | repo `<tag>` finding `<ID>` | <date> |

---

## External resources to budget

| Type | Description | Estimated cost |
|------|-------------|----------------|
| Legal review | <description> | €<n> one-time |
| Service upgrade | <description> | €<n>/mo recurring |
| Tooling | <description> | €<n> one-time |
| Professional audit | <description> | €<n> one-time |

---

## Conclusions

<3-5 paragraphs synthesizing findings, prioritization, and the practical roadmap for the next 3 months.>

---

## Files in this audit

- `REPORT.md` — this consolidation
- `audit-A.md` — Phase A detail (with evidence dashboard)
- `audit-B.md` — Phase B detail (with evidence dashboard)
- `audit-C.md` — Phase C detail (with evidence dashboard)
- `audit-D.md` — Phase D detail (with evidence dashboard)
- `findings.json` — machine-readable, queryable findings (schema v2.0)
- `roadmap.md` — sprint-organized remediation plan
- `state.json` — resume state for `--resume` mode

---

*Generated by `/mariana` skill v2. Powered by [graphify](https://github.com/safishamsi/graphify). Licensed MIT.*
