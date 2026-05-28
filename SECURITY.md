# Security Policy

## Supported versions

Only the latest minor version on `main` is actively supported. Older tags are frozen.

| Version | Supported |
|---------|-----------|
| 1.x     | ✓ |
| < 1.0   | ✗ |

## Reporting a vulnerability

If you find a security issue in the skill itself (e.g. one of the playbooks introduces a regression, the installer creates a misconfiguration, a script could be abused), **do not open a public issue**. Email the maintainer:

**security@ibaifernandez.com**

Or send a private security advisory via GitHub:
https://github.com/ibaifernandez/mariana-audit/security/advisories/new

Include:

- Description of the issue and impact.
- Steps to reproduce (or a proof-of-concept).
- The version / commit SHA where you observed it.
- Any suggested mitigation.

## Response timeline

| Step | Target |
|------|--------|
| Acknowledgement of report | Within 48 hours |
| Triage + severity assessment | Within 7 days |
| Public fix on `main` | Depends on severity (CRITICAL: <72h; HIGH: <2 weeks; otherwise: best-effort) |
| Public advisory + CVE request if applicable | After fix is merged |

## Scope

In scope:

- The skill's own scripts (`bootstrap/*.sh`, `bootstrap/*.py`).
- The skill's playbooks recommending insecure patterns.
- Templates that could be exploited if blindly trusted by downstream automation.

Out of scope (report to the upstream project):

- Vulnerabilities in [graphify](https://github.com/safishamsi/graphify) — report there.
- Vulnerabilities in Claude Code itself — report to Anthropic.
- Vulnerabilities in your own codebase surfaced by an audit — those go in your own issue tracker.

## Safe harbor

Good-faith research that follows this policy will not result in legal action from the maintainers.

Thank you for helping keep this skill safe.
