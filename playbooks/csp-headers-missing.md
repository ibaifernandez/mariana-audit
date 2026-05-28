# Playbook — Missing CSP / HSTS / X-Frame / Permissions-Policy headers

**Severity:** HIGH (defense-in-depth gap)
**OWASP:** A05:2021 Security Misconfiguration
**Empirically validated:** Detected in `aglaya-kanban-desk` audit, finding B-05 (May 2026).

---

## Detection

```bash
# 1. Check the live response from production
curl -sIL https://<your-app>/ | grep -iE "content-security-policy|strict-transport-security|x-frame-options|x-content-type-options|referrer-policy|permissions-policy"
# Each missing header is a separate finding.

# 2. If hosted on Netlify, check the config
cat netlify.toml 2>/dev/null | grep -A 5 "^\[\[headers\]\]"
ls public/_headers _headers 2>/dev/null

# 3. If hosted on Vercel, check the config
cat vercel.json 2>/dev/null | grep -A 5 "headers"

# 4. If served from the application server (Express/FastAPI), check middleware
grep -rn "helmet\|Helmet\|setHeader.*Content-Security-Policy" server/
```

The HTML response from any user-facing surface MUST include all six headers below. APIs SHOULD include them too (helmet middleware default is sufficient).

---

## Risk narrative

These headers are defense-in-depth controls. Each one closes off a category of attacks:

| Header | What it blocks if present | What's open without it |
|--------|---------------------------|------------------------|
| `Content-Security-Policy` | Inline `<script>`, untrusted external scripts, data exfiltration via image/form/connect | Any XSS becomes much easier; any compromised dep can call out |
| `Strict-Transport-Security` | Downgrade attacks (https → http) | First-visit MITM is possible |
| `X-Frame-Options` / CSP `frame-ancestors` | Clickjacking via iframe | Attacker can frame your app and steal clicks |
| `X-Content-Type-Options: nosniff` | MIME sniffing turning text/plain → text/html | Uploaded files served with wrong type can execute |
| `Referrer-Policy` | Full URL leakage to third-party sites in `Referer` | Auth tokens in URLs leak to ad networks |
| `Permissions-Policy` | Implicit access to camera/microphone/geolocation by embedded content | Third-party iframe can request mic without your control |

Even if you have other layers (CSRF tokens, secure cookies, etc.), missing these headers gives attackers cheap optionality.

---

## Mitigation

### If hosted on Netlify

Add or extend `netlify.toml`:

```toml
[[headers]]
  for = "/*"
  [headers.values]
    Strict-Transport-Security = "max-age=31536000; includeSubDomains; preload"
    X-Frame-Options           = "DENY"
    X-Content-Type-Options    = "nosniff"
    Referrer-Policy           = "strict-origin-when-cross-origin"
    Permissions-Policy        = "camera=(), microphone=(), geolocation=(), payment=(), usb=(), accelerometer=(), gyroscope=(), magnetometer=()"
    Content-Security-Policy   = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://api.example.com; frame-ancestors 'none'; form-action 'self'; base-uri 'self'; object-src 'none'"
```

**CSP requires tuning per project.** Start with the policy above and inspect the browser console for violations. Add domains to the relevant directives one at a time.

If you cannot get rid of `'unsafe-inline'` for `style-src` (common with Tailwind + dynamic classes), document the residual risk in the audit report and add `nonce-` or `hash-` based mitigations for the inline scripts.

### If hosted on Vercel

Use `vercel.json`:

```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Strict-Transport-Security", "value": "max-age=31536000; includeSubDomains; preload" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
        { "key": "Permissions-Policy", "value": "camera=(), microphone=(), geolocation=()" },
        { "key": "Content-Security-Policy", "value": "default-src 'self'; ..." }
      ]
    }
  ]
}
```

### If served from Express

```javascript
const helmet = require('helmet');

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      fontSrc: ["'self'", "data:"],
      connectSrc: ["'self'", "https://api.example.com"],
      frameAncestors: ["'none'"],
      formAction: ["'self'"],
      baseUri: ["'self'"],
      objectSrc: ["'none'"],
    },
  },
  strictTransportSecurity: { maxAge: 31536000, includeSubDomains: true, preload: true },
  frameguard: { action: 'deny' },
  noSniff: true,
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  permittedCrossDomainPolicies: { permittedPolicies: 'none' },
}));
```

### If served from FastAPI

```python
from fastapi import FastAPI
from starlette.middleware.base import BaseHTTPMiddleware

CSP = "default-src 'self'; script-src 'self'; ..."  # tune per project

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        response.headers["Content-Security-Policy"] = CSP
        return response

app.add_middleware(SecurityHeadersMiddleware)
```

---

## Smoke / verification

```bash
# After deploy, verify all 6 headers are present:
for h in "content-security-policy" "strict-transport-security" "x-frame-options" "x-content-type-options" "referrer-policy" "permissions-policy"; do
  curl -sIL https://<your-app>/ | grep -i "^$h:" && echo "  ✓ $h" || echo "  ✗ $h MISSING"
done

# Run a third-party scanner
curl -s "https://securityheaders.com/?q=https://<your-app>&hide=on&followRedirects=on" | grep -i "grade"
# Aim for grade A or A+.
```

---

## Commit message template

```
fix(security): add CSP / HSTS / X-Frame / Permissions-Policy headers (mitigates B-05)

Production HTML responses lacked CSP, HSTS, X-Frame-Options,
X-Content-Type-Options, Referrer-Policy and Permissions-Policy.
Defense-in-depth gap — any XSS that slips through is much easier
to exploit without these layers.

Policy applied via netlify.toml [[headers]] block. CSP tuned per
project: 'self' baseline, with explicit allowlists for known
third-party connectors. Inline styles allowed via 'unsafe-inline'
(residual risk documented).

Verified via curl -I + securityheaders.com (grade <A>).

Identified during Mariana Trench audit, finding ID <ID>.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Follow-up hardening

- Replace `'unsafe-inline'` with nonces or hashes.
- Add `report-uri` / `report-to` directive to collect violation reports.
- Enable HSTS preload by submitting to https://hstspreload.org/ (one-way commitment — verify config first).
- Implement Subresource Integrity (SRI) for any third-party scripts you do allow.
