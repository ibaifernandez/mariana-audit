# Contributing to mariana-audit

Thanks for considering a contribution. This skill grows through **playbooks** — validated end-to-end mitigations for patterns that audits surface in real production codebases. Each new playbook makes the skill more valuable for everyone.

There are also opportunities to refine **rubrics**, add **stack-specific scope adaptations**, and improve **bootstrap installers**.

---

## Quick start for contributors

```bash
# Fork + clone
git clone https://github.com/<your-fork>/mariana-audit
cd mariana-audit

# Symlink to your Claude Code skills dir for local testing
mkdir -p ~/.claude/skills
ln -s "$(pwd)" ~/.claude/skills/mariana-audit

# Test by running the skill against a known repo
cd /path/to/test/repo
# In a Claude Code session: /mariana
```

When done, open a PR from your fork.

---

## Contribution types

### 1. New playbook (most wanted)

A playbook is a self-contained markdown file in `playbooks/` that codifies an end-to-end mitigation for a specific finding pattern. Use `playbooks/xss-svg-upload.md` or `playbooks/supabase-free-backup-r2.md` as references.

**Required sections in every playbook:**

```markdown
# Playbook — <descriptive title>

**Severity:** <CRITICAL | HIGH | MEDIUM | LOW>
**Severity metadata:** <CVSS string for security, WCAG criterion for a11y, etc.>
**OWASP / standard:** <category reference>
**Empirically validated:** <yes — commit SHA + repo + date | no — theoretical>

## Detection
<bash commands or graphify queries that surface the finding>

## Risk narrative
<exploit chain or operational impact, 1-3 paragraphs>

## Mitigation
<step-by-step, defense in depth where possible>

## Regression tests
<test code reusable in target project>

## Smoke / verification
<commands to validate the fix in dev + production>

## Commit message template
<message that links back to the audit ID>

## Follow-up hardening
<long-term improvements, e.g. sandbox subdomain for uploads>
```

**A playbook is mergeable when:**

1. It cites the OWASP/CVSS/WCAG/regulation reference where applicable.
2. The mitigation is multi-layer (defense in depth) when possible.
3. Regression tests are included.
4. It has been **applied in at least one real repo with a verifiable SHA** OR it is marked `validated: false` and clearly labeled as theoretical.

### 2. Rubric refinement

The severity rubrics in `rubrics/severity.md` are calibrated against published standards. Refinements are welcome when:

- A standard has been updated (e.g. WCAG 2.2 → 3.0 transitions).
- A new regulation comes into scope (e.g. China PIPL).
- An existing escalation rule produces too many false positives in real audits.

Cite the source standard. Don't add opinions without rubric backing.

### 3. Stack-specific scope adaptation

The skill currently has defaults for: SaaS-with-backend-and-DB, static vitrina, CLI / library, public API, internal auth-walled tool. Adaptations welcome for:

- Rails / Django / .NET / Spring conventions.
- Mobile native apps (iOS, Android).
- Browser extensions.
- WordPress / drupal / similar CMS.
- Game development.

A stack-specific adaptation lives in `SKILL.md` under "Archetype-specific defaults" with: detection heuristics + dimension applicability + dimension-specific defaults.

### 4. Bootstrap installer improvements

`bootstrap/install.sh` and `bootstrap/check-cooldown.sh` are intentionally portable shell. PRs that improve portability (more BSD/GNU `date` compatibility, Windows WSL support, etc.) are welcome.

---

## Code style

- **Shell scripts:** POSIX-compatible where possible, `set -euo pipefail`, idempotent, env-var-controlled bypasses (`SKIP_*=1`).
- **Python scripts:** Python 3.10+, no external deps unless absolutely necessary, type hints when reasonable.
- **Markdown:** ATX-style headings, tables aligned, code blocks language-tagged.

---

## Testing your changes

Manual testing against a real repo is the gold standard. At minimum:

1. Run `bootstrap/install.sh` against a fresh repo and verify all five steps pass idempotently.
2. Run `bootstrap/check-cooldown.sh` in a repo with no audit and verify `FRESH`. In a repo with a recent audit dir and few commits since, verify `SKIP`.
3. If you added a playbook, run an audit in `--mode mitigate` mode against a known-vulnerable test fixture and verify the mitigation lands.

---

## PR review criteria

PRs will be reviewed for:

1. **Empirical grounding.** Did this come from a real audit, or is it theoretical? Theoretical is fine, just label it.
2. **Honesty.** No invented CVSS / WCAG / regulation references. If unsure, omit and mark `[NOT VERIFIABLE]`.
3. **Reusability.** Will this playbook help others, or is it too project-specific?
4. **Documentation.** Reader (not just author) can apply the playbook without further context.
5. **Backward compatibility.** Existing audits using the previous output schema continue to validate.

---

## Commit message style

Conventional commits:

- `feat(playbook): jwt-long-ttl-no-refresh` for new playbooks
- `fix(installer): handle BSD date on macOS` for fixes
- `docs(rubric): clarify WCAG AAA scope` for documentation
- `chore: update deps` for housekeeping

---

## Code of conduct

Be excellent. Be technically honest. Don't ship hype.

---

## License

By contributing, you agree your contributions are licensed under MIT (see `LICENSE`).

Thank you for making this skill better.
