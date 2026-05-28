# Mariana Audit Report — <REPO_NAME>

**Audit ID:** `<repo>-YYYY-MM-DD-mariana`
**Mode:** `report | mitigate | case-by-case`
**Started:** YYYY-MM-DD HH:MM UTC
**Finished:** YYYY-MM-DD HH:MM UTC
**Repo commit at start:** `<sha>`
**Repo commit at end:** `<sha>`
**Auditor:** `mariana-audit` skill (Powered by graphify)

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
| CRÍTICO mitigated during audit | <n> |
| CRÍTICO open | <n> |
| ALTO     | <n> |
| MEDIO    | <n> |
| BAJO     | <n> |
| INFO / N-A | <n> |
| [NO VERIFICABLE] | <n> |
| **Total findings** | **<n>** |

---

## Scope confirmation

| # | Dimension | Applicable | Reason / Notes |
|---|-----------|------------|----------------|
| 1 | Seguridad | SÍ / N/A | |
| 2 | Accesibilidad WCAG 2.1 | SÍ / N/A | |
| 3 | Usabilidad | SÍ / N/A | |
| 4 | Performance | SÍ / PARCIAL | <CWV NO VERIFICABLE sin Lighthouse remoto> |
| 5 | Bases de datos | SÍ / N/A | |
| 6 | SEO técnico | SÍ / N/A | |
| 7 | Arquitectura + deuda | SÍ | |
| 8 | Cumplimiento legal | SÍ / N/A | |
| 9 | Cookies + consent | SÍ / N/A | |
| 10 | Data retention + DPA | SÍ / N/A | |
| 11 | DevOps / CI | SÍ | |
| 12 | Despliegue + observabilidad | SÍ / PARCIAL | |
| 13 | Docs + mantenibilidad | SÍ | |

---

## Fase A — Producto cara al usuario

**Findings count:** <n> (CRÍTICO: <n>, ALTO: <n>, MEDIO: <n>, BAJO: <n>)

Per-finding detail in `audit-A.md`. Top critical highlighted below.

### Top critical findings

| ID | Hallazgo (1 línea) | Evidencia | WCAG / norma | Severidad |
|----|--------------------|-----------|--------------|-----------|
| A-XX | <título> | `<file:line>` | `<criterion>` | CRÍTICO |

---

## Fase B — Backend + Datos + Arquitectura

**Findings count:** <n> (CRÍTICO: <n>, ALTO: <n>, MEDIO: <n>, BAJO: <n>)

Per-finding detail in `audit-B.md`.

### Clean verifications (positive findings — no issue)

✓ <verification 1>
✓ <verification 2>
...

### Top critical findings (security + DB)

| ID | Hallazgo | Evidencia | OWASP / CVSS | Severidad | Estado |
|----|----------|-----------|--------------|-----------|--------|
| B-CRIT-XX | <título> | `<file:line>` | `<OWASP / CVSS>` | CRÍTICO | MITIGATED `<sha>` / OPEN |

### Architecture findings

- God nodes top-5 with reading of `degree` + cohesion + community.
- Cross-canon patterns inherited (if global graph available).

---

## Fase C — Cumplimiento legal

**Findings count:** <n> (CRÍTICO: <n>, ALTO: <n>, MEDIO: <n>, BAJO: <n>)

Per-finding detail in `audit-C.md`.

### Positive findings (compliance already in place)

✓ <e.g. privacy policy aglaya.biz exists trilingual>
✓ <e.g. CORS allowlist explicit production-scoped>

### Critical findings (regulatory)

| ID | Hallazgo | Reg / Art. | Subjects affected | Severidad |
|----|----------|------------|--------------------|-----------|
| C-XX | <título> | `<Reg. Art.>` | <EU / Chile / Brazil / California / all> | CRÍTICO |

### Operational legal items (require human action)

- DPAs to accept in vendor dashboards: <list>
- Privacy policy draft + review: estimated €<n>
- DPO contact decision (who, how published): pending

---

## Fase D — Ops + Mantenibilidad

**Findings count:** <n>

Per-finding detail in `audit-D.md`.

### Top critical findings

| ID | Hallazgo | Evidencia | Severidad |
|----|----------|-----------|-----------|

---

## Mitigations applied during this audit (mode `mitigate` or `case-by-case`)

| Finding | Playbook used | SHA | Verified |
|---------|---------------|-----|----------|
| B-CRIT-01 XSS | `xss-svg-upload.md` | `<sha>` | ✓ |
| B-CRIT-02 backup | `supabase-free-backup-r2.md` | `<sha>` | ✓ |

---

## NO VERIFICABLE items

Items that could not be verified from inside the audit. Each requires external action.

| ID | Description | Why not verifiable | Recommended external action |
|----|-------------|--------------------|-----------------------------|
| <ID> | <desc> | <reason> | <action> |

---

## Priority matrix

P0 = close in Sprint 1 (CRITICAL + legal exposure)
P1 = ALTO Sprint 2 (4 weeks)
P2 = MEDIO Sprint 3+
P3 = BAJO / nice-to-have backlog

| Finding | Severidad | Effort (h) | Impacto | Prioridad |
|---------|-----------|-----------|---------|-----------|
| <ID> | <sev> | <h> | <user / business / regulatory> | <P0-P3> |

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

Findings whose detection or severity was informed by patterns previously caught in other repos of the global graph.

| Current finding | Pattern from | Original audit |
|-----------------|--------------|----------------|
| <ID> | repo `<tag>` finding `<ID>` | <date> |

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
- `audit-A.md` — Fase A detail
- `audit-B.md` — Fase B detail
- `audit-C.md` — Fase C detail
- `audit-D.md` — Fase D detail
- `findings.json` — machine-readable, queryable findings
- `roadmap.md` — sprint-organized remediation plan
- `state.json` — resume state for `--resume` mode

---

*Generated by `/mariana` skill. Powered by [graphify](https://github.com/safishamsi/graphify). Licensed MIT.*
