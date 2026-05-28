# Examples

Sample outputs from real audit runs, sanitized to remove identifiable data.

## `sample-audit-2026-05-27-mariana/`

A sanitized version of the audit that produced this skill — an Express + Supabase + React multi-tenant app run in `--mode mitigate`.

- **48 findings** across 5 fases (0 / A / B / C / D), with E synthesizing into a sprint-organized roadmap.
- **2 CRITICAL mitigated in-flight** during the audit: XSS via SVG upload (CVSS 8.0) and Supabase Free without backups (catastrophic operational).
- **5 CRITICAL open** in Fase C (legal compliance — privacy policy, DPA registry, self-delete + self-export endpoints).
- **Graph leverage ratio: 56%** (above the 50% target).

Files in the example:

```
sample-audit-2026-05-27-mariana/
└── REPORT.md      # the consolidated report shown here
```

The complete audit output would also contain `audit-A.md` / `audit-B.md` / `audit-C.md` / `audit-D.md` (per-fase detail), `findings.json` (machine-readable), `roadmap.md` (sprint-organized), and `state.json` (resume state).

Use this example to:

- See what the skill produces before running it on your own repo.
- Calibrate expectations on finding density and severity distribution.
- Reference the citation style and evidence format for contributing playbooks.

---

**Sanitization notes:**

- All domain names replaced with `<your-app>` / `<org-site>` / `web-production-xxx.up.railway.app`.
- Commit SHAs replaced with placeholders (`aaaa111`, `bbbb222`, `cccc333`).
- File paths kept generic (`server/routes/uploads.js` style).
- Severity counts and rubric references are authentic to the original audit.
