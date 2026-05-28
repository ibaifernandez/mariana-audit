# Remediation Roadmap — <REPO_NAME>

**Source audit:** `docs/audits/<YYYY-MM-DD>-mariana/REPORT.md`
**Generated:** <YYYY-MM-DD>

Each finding is prioritized P0 (close in Sprint 1) through P3 (backlog). Items already MITIGATED during the audit are recorded with their SHAs but excluded from sprints.

---

## P0 — Sprint 1 (within 2 weeks)

CRITICAL items + legal exposure. Must be closed before scaling users or launching to new audiences.

| Finding | Effort | Owner | Notes |
|---------|--------|-------|-------|
| <ID> <title> | <h> | <owner> | <playbook? external resource? decision needed?> |

Estimated total: <h> hours.

---

## P1 — Sprint 2 (within 4 weeks)

HIGH severity. Significant risk or degradation. Block on Sprint 1 closing.

| Finding | Effort | Owner | Notes |
|---------|--------|-------|-------|
| <ID> <title> | <h> | <owner> | <notes> |

Estimated total: <h> hours.

---

## P2 — Sprint 3+

MEDIUM severity. Schedule per bandwidth.

| Finding | Effort | Owner | Notes |
|---------|--------|-------|-------|
| <ID> <title> | <h> | <owner> | <notes> |

---

## P3 — Backlog

LOW + nice-to-have. Pick up opportunistically.

| Finding | Effort | Owner | Notes |
|---------|--------|-------|-------|
| <ID> <title> | <h> | <owner> | <notes> |

---

## NO VERIFICABLE — external dependencies

These cannot be closed in code. They require third-party action or external tools.

| Finding | What's needed | Owner | Estimated timeline |
|---------|---------------|-------|--------------------|
| <ID> <title> | <external dependency> | <owner> | <date or "ad-hoc"> |

---

## Mitigated during this audit

For history. Do not re-open unless regression.

| Finding | SHA | Playbook | Verified |
|---------|-----|----------|----------|
| <ID> <title> | <sha> | <playbook> | yes/no |

---

## External resources to budget

- **Legal review** of privacy policy + DPAs: estimated €<n> — <n> hours of legal counsel time.
- **Professional accessibility audit** (e.g. WebAIM, Deque): estimated €<n>.
- **Penetration test** (when scaling): estimated €<n>.
- **Supabase Pro upgrade** ($25/mo) to retire custom backup workflow.
- Other: <items>

Total external budget recommended: €<n> one-time + €<n>/mo recurring.
