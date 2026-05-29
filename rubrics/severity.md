# Severity Rubric — Mariana Audit

This rubric is non-negotiable. Every finding gets a severity. If you cannot justify the severity per this rubric, the finding is informational (INFO), not low-severity.

---

## Security — CVSS 3.1 + OWASP

| Severity | CVSS Score | What it means |
|----------|-----------|---------------|
| CRITICAL  | 9.0–10.0  | Active, large-impact exploitation possible. Drop everything. |
| HIGH     | 7.0–8.9   | Significant impact; auth user or chained vector. Sprint 1. |
| MEDIUM    | 4.0–6.9   | Lower impact or higher complexity. Sprint 2-3. |
| LOW     | 0.1–3.9   | Minor / informational with security relevance. Backlog. |

**Mandatory fields per security finding:**

- CVSS 3.1 vector string (e.g. `AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:H/A:L`)
- CVSS base score (calculator: https://www.first.org/cvss/calculator/3.1)
- OWASP Top 10 2021 category (`A01` through `A10`)
- Attack vector summary (1 sentence)
- Required attacker privileges (None / Authenticated User / Admin)
- User interaction required (Yes / No)
- Scope changed (Yes / No)
- Impact triad: Confidentiality (None / Low / High), Integrity (idem), Availability (idem)

---

## Accessibility — WCAG 2.1

| Severity | WCAG criterion level | What it means |
|----------|---------------------|---------------|
| CRITICAL  | Level A failure     | Blocks usage for a group of users entirely. |
| HIGH     | Level AA failure    | Significant barrier for users with disabilities. |
| MEDIUM    | Level AAA failure   | Best-practice gap (not legally mandatory in most contexts). |
| LOW     | Best-practice (no WCAG criterion) | Improvement, not a barrier. |

**Mandatory fields per a11y finding:**

- WCAG version (e.g. 2.1 or 2.2)
- WCAG criterion (e.g. `2.1.1 Keyboard`, `1.3.1 Info and Relationships`)
- WCAG level (A / AA / AAA)
- Affected user group (keyboard-only, screen reader, low vision, motor impairment, cognitive)

---

## Legal compliance — per-article

| Severity | Trigger |
|----------|---------|
| CRITICAL  | Direct violation of a fundamental obligation: privacy policy absent, no DPA registry, no self-delete/self-export endpoint, breach notification process absent, unauthorized international transfer. |
| HIGH     | Significant gap: legal basis not declared, TOMs not documented, retention period not specified, DPIA missing for high-risk processing. |
| MEDIUM    | Documentation gaps: RAT not formal, DPO contact not public, internal training not recorded. |
| LOW     | Nice-to-have: consent banner aesthetic improvement, language localization. |

**Mandatory fields per legal finding:**

- Regulation name (GDPR / Ley 21.719 / LGPD / CCPA / other)
- Article reference (e.g. `GDPR Art. 13`, `Ley 21.719 Art. 14 ter`)
- Affected data subject (EU residents / Chile residents / Brazil residents / California residents / all)
- Fine exposure if known (e.g. `GDPR up to 4% global revenue or €20M`, `Ley 21.719 up to 5,000 UTM`)

---

## Database / Operational

| Severity | Trigger |
|----------|---------|
| CRITICAL  | Catastrophic data loss possible: no backups + no PITR (e.g. Supabase Free); RLS off on tables with sensitive data + client-side direct access. |
| HIGH     | Significant operational risk: missing indexes causing query timeouts; FK constraints incomplete; no monitoring on critical metrics. |
| MEDIUM    | Hardening gaps: defense-in-depth missing (e.g. RLS enabled but only `service_role` used and bypasses it); slow but functional queries. |
| LOW     | Schema hygiene: dead columns, untyped columns, no soft-delete. |

---

## Architecture / Technical Debt

| Severity | Trigger |
|----------|---------|
| CRITICAL  | Single-point-of-failure that blocks development (e.g. one undocumented mega-function that everyone modifies); circular dependencies causing build failures. |
| HIGH     | Significant maintenance cost: god nodes with high coupling (degree > 30 + low cohesion); business logic in routes (untestable). |
| MEDIUM    | Coupling worth refactoring opportunistically: components > 700 LOC; duplicate helpers across modules. |
| LOW     | Code smell with no current pain: inconsistent naming, missing types. |

**Important: god-node `degree` measures surface of imports, NOT acoupling.** A router that delegates 5 endpoints to 5 services will have `degree=29` and be perfectly factored. Read the code before recommending refactor.

---

## DevOps / Observability

| Severity | Trigger |
|----------|---------|
| CRITICAL  | No deploy rollback path; no backup verification ever performed; secrets in repo history. |
| HIGH     | No CI for tests/build/lint; no error tracking; no alerts on critical metrics; manual deploys with high human-error risk. |
| MEDIUM    | No structured logs; no uptime monitoring; outdated dependencies with known CVEs; no linter/types. |
| LOW     | No runbooks for non-critical procedures; AGENTS.md/CLAUDE.md not maintained. |

---

## Documentation / Maintainability

| Severity | Trigger |
|----------|---------|
| CRITICAL  | README points to broken/outdated build steps that block new contributors. |
| HIGH     | ADRs missing for major architectural decisions; onboarding doc absent for team that has new joiners. |
| MEDIUM    | Glossary missing; API not documented (OpenAPI/Swagger). |
| LOW     | Code comments sparse; CHANGELOG not maintained. |

---

## Cross-cutting severity escalation rules

These rules **automatically escalate** severity beyond the per-dimension rubric:

1. **Active exploitation observed** → automatic CRITICAL IMMEDIATE.
2. **Combined factor: known regulatory deadline within 30 days** → +1 severity tier.
3. **Combined factor: handling sensitive data (health, finance, minors, religion, biometrics)** → +1 tier for any related security/legal finding.
4. **Combined factor: production data affected (not staging or dev)** → +1 tier for any backup/restore-related finding.
5. **Combined factor: customer-facing product (vs internal tool)** → +1 tier for any a11y or UX finding affecting purchase/conversion paths.

---

## Severity reduction rules

These **reduce** severity automatically:

1. **Already mitigated via another layer**: e.g. a missing RLS policy where all code paths go through `service_role` server-side. Document as "latent" rather than active.
2. **No path to exploitation in this codebase**: e.g. SSRF concern but `httpx` configured with `follow_redirects=False`.
3. **Pre-existing test/security debt explicitly tracked** in `docs/known-debt.md`: severity stays in `MEDIUM` ceiling unless escalated by another rule.

---

## When severity is contested

If the auditor (you) and the reviewer (user) disagree on severity:

- Re-cite the rubric criterion that justifies your call.
- If the finding lacks the mandatory fields, the reviewer is correct to demand them or downgrade.
- If you can't produce CVSS / WCAG ref / regulation article, downgrade automatically.
