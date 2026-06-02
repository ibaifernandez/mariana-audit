# Confidence Tier Rubric — Mariana Audit

Every finding carries a `confidence_tier`. This field is **mandatory**. A finding without it is not emitted — it is dropped.

---

## The three tiers

### PROVEN

Evidence is a specific `file:line` with a code snippet, or a tool output with exact reproducible content.

**All must hold:**
- `evidence_source` = `code-read` OR `tool-external` OR `manual-verification`
- At least one evidence item has `file` + `line` (or equivalent tool output with exact content)
- Finding existence is not conditional on runtime behavior

**Cannot be PROVEN:**
- Any finding derived solely from graphify queries without code verification
- Any finding that requires checking an external dashboard or runtime state

### SUSPECTED

Evidence is structural — the pattern is consistent with an issue but not directly verified at the code level.

**All must hold:**
- `evidence_source` = `graph-local` OR `graph-global`
- A specific graphify query or explain result surfaced the pattern (cite the query)
- The pattern has not been verified by reading the relevant file:line

**Action for SUSPECTED findings:**
Always attempt code verification: `grep` or Read the relevant file.
- Verification succeeds → upgrade to PROVEN
- File not found or pattern absent → downgrade to UNVERIFIABLE

### UNVERIFIABLE

Evidence cannot be gathered from inside the audit without external access or runtime context.

**Mandatory subtype — pick the most specific:**

| Subtype | Trigger |
|---------|---------|
| `NV_RUNTIME` | Requires Lighthouse, browser session, or deployed authenticated state (Core Web Vitals, INP, real user behavior) |
| `NV_DASHBOARD` | Requires logging into a vendor dashboard (Supabase plan tier, Cloudflare WAF rules, Sentry org settings) |
| `NV_CREDENTIALS` | Requires admin credentials or internal system access not available during the audit |
| `NV_TOOL` | Requires an external tool not installed (`axe-core`, `radon`, `pip-audit`, `eslint-plugin-complexity`, etc.) |

**For every UNVERIFIABLE finding:**
- State the specific reason and subtype
- Provide a concrete recommended external action
- Severity may still be assigned if absence is itself the evidence (e.g. "no `robots.txt` exists" is PROVEN-absent, not UNVERIFIABLE)

---

## Enforcement gate

| Violation | Consequence |
|-----------|-------------|
| `confidence_tier` absent | Finding dropped — not emitted |
| Claims `PROVEN` without `file:line` or tool output | Downgraded to `SUSPECTED` |
| Claims `SUSPECTED` without citing a graphify query result | Downgraded to `UNVERIFIABLE` |
| `UNVERIFIABLE` without subtype | Finding dropped — not emitted |

These rules are not advisory. They are automatic. Apply them before writing any finding to the output file.

---

## Per-phase evidence dashboard

At the **top** of every `audit-X.md`, before any findings table, include:

```
## Evidence Dashboard — Phase X

| Confidence   | Count | % of phase |
|--------------|-------|------------|
| PROVEN       | <n>   | <pct>%     |
| SUSPECTED    | <n>   | <pct>%     |
| UNVERIFIABLE | <n>   | <pct>%     |
| **Total**    | **<n>** | 100%     |

Evidence source breakdown: code-read <n> · graph-local <n> · graph-global <n> · tool-external <n> · manual-verification <n>
```

**Health signal:** PROVEN ≥ 60% = healthy. If SUSPECTED > 40%, attempt code verification on the top 5 suspected findings before finalizing the phase. Document the attempt even if it fails (the downgrade to UNVERIFIABLE is the correct outcome).

---

## Regression delta (Phase E only)

When a previous `findings.json` exists for this repo, compare against it and assign a `regression_status` to each finding:

| Status | Meaning |
|--------|---------|
| `NEW` | Not present in previous audit |
| `FIXED` | Was OPEN, now MITIGATED or absent |
| `REGRESSED` | Was MITIGATED, now OPEN again |
| `UNCHANGED` | Same status, same severity as previous |
| `ESCALATED` | Same finding, severity went up |
| `DEESCALATED` | Same finding, severity went down |

Surface the delta as a dedicated section in Phase E synthesis before the priority matrix. A `REGRESSED` finding is always P0 regardless of severity — a fix that didn't hold is a process failure, not a backlog item.
