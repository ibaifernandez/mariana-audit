# Playbook — Default platform URL publicly exposed (Railway / Vercel / Render / etc.)

**Severity:** HIGH (information disclosure + proxy bypass)
**OWASP:** A05:2021 Security Misconfiguration + A04:2021 Insecure Design
**Empirically validated:** Detected in `aglaya-kanban-desk` audit, finding B-03 (May 2026).

---

## Detection

```bash
# 1. Inspect deployment configs for the platform-default hostname
grep -rn "railway.app\|vercel.app\|onrender.com\|fly.dev\|herokuapp.com\|netlify.app" \
  netlify.toml vercel.json *.yml *.json README.md docs/ 2>/dev/null

# 2. Try the default URL directly without going through your custom domain
DEFAULT_URL="<the platform-default URL e.g. web-production-xxx.up.railway.app>"
curl -i "https://$DEFAULT_URL/api/health"
# If you get a 200 with real data → information disclosure + proxy bypass confirmed.

# 3. Check whether the API enforces an Origin / Host check
grep -rn "req.headers.host\|req.headers.origin\|allowedHosts" server/
```

If the default URL responds with real data (not a generic 404) → **HIGH**.

---

## Risk narrative

A public default platform URL like `web-production-xxx.up.railway.app` is two problems in one:

1. **Information disclosure.** Anyone reading network traffic or DNS history knows your provider, region, and exact instance name. Targeted attacks become easier.
2. **Proxy bypass.** Your custom domain (e.g. `app.example.com`) likely proxies through a CDN (Cloudflare, Netlify, etc.) that applies WAF rules, rate limits, logging, and bot protection. An attacker who finds the default URL bypasses all of that and talks to the origin directly.

Specifically, if you stole a JWT through any other vector, you can now use it against the origin URL **without leaving a trace in your CDN logs**.

---

## Mitigation — three options

### Option 1 — Cloudflare WAF rule (recommended if you use Cloudflare)

In Cloudflare dashboard:

1. Open the zone of your custom domain.
2. Security → WAF → Custom rules → Create.
3. Rule:
   - **Expression:** `(http.host eq "web-production-xxx.up.railway.app")`
   - **Action:** Block.

If you do not use Cloudflare for your custom domain, you cannot block the default URL at the CDN level (Cloudflare cannot intercept requests that never go through it). Use Option 2 or 3 instead.

### Option 2 — Express middleware (works on any platform)

```javascript
// At the top of your middleware stack, before any routes
const ALLOWED_HOSTS = new Set([
  'app.example.com',
  'staging.app.example.com',
]);

const ALLOWED_HOSTS_DEV = new Set([
  'localhost',
  '127.0.0.1',
  ...ALLOWED_HOSTS,
]);

app.use((req, res, next) => {
  const allowed = process.env.NODE_ENV === 'production' ? ALLOWED_HOSTS : ALLOWED_HOSTS_DEV;
  const host = (req.headers.host || '').split(':')[0].toLowerCase();
  if (!allowed.has(host)) {
    return res.status(421).send('Misdirected Request');
  }
  next();
});
```

HTTP 421 "Misdirected Request" is the standards-compliant response for this case (RFC 7540 §9.1.2).

### Option 3 — Require a shared secret on requests from the proxy

If the proxy (Netlify, Cloudflare, etc.) supports setting a custom header on forwarded requests, configure that. Then validate it server-side:

```javascript
// netlify.toml — adds an internal header on every proxied request
// [[redirects]]
//   from = "/api/*"
//   to = "https://api.example.com/:splat"
//   status = 200
//   force = true
//   headers = { X-Proxy-Token = "from-env-var" }

const PROXY_TOKEN = process.env.PROXY_TOKEN;

app.use((req, res, next) => {
  if (req.path.startsWith('/api/') && req.headers['x-proxy-token'] !== PROXY_TOKEN) {
    return res.status(421).send('Misdirected Request');
  }
  next();
});
```

This blocks any direct hits on the default URL because they lack the header.

### Option 4 — Disable the default URL entirely (best, when supported)

Some platforms allow disabling the auto-generated subdomain:

- **Railway:** Settings → Networking → "Public Networking" → toggle off the auto-generated domain. Only the custom domain remains.
- **Vercel:** custom domain config can include "remove default" via the dashboard.
- **Render:** custom-domain-only mode is supported.
- **Fly.io:** `fly.toml [http_service]` can be set to require host header validation.

If your platform supports this, use it. It is the cleanest fix.

---

## Smoke / verification

```bash
# After applying mitigation, the default URL must NOT respond with real data
curl -i "https://web-production-xxx.up.railway.app/api/health"
# Expected: HTTP 421 Misdirected Request (or 403, or connection failure)

# Custom domain must keep working
curl -i "https://app.example.com/api/health"
# Expected: HTTP 200 OK
```

---

## Commit message template

```
fix(security): block default Railway URL — enforce custom-host allowlist (mitigates B-03)

The platform-default URL web-production-xxx.up.railway.app was publicly
accessible, exposing the provider/region and offering a bypass of the
CDN-level WAF + logging that the custom domain provides. Any stolen
JWT could be used against the origin URL without leaving CDN traces.

Added Express middleware that rejects HTTP 421 if Host header is not
in the allowed custom-domain list. Production allowlist:
- app.example.com
- staging.app.example.com

Verified default URL now returns 421 while custom domain remains 200.

Identified during Mariana Trench audit, finding ID <ID>.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Follow-up hardening

- If the platform supports disabling the default URL outright, do that and remove the middleware.
- Move the WAF rule to your CDN provider so the request is blocked before it ever touches the origin.
- Add monitoring/alerting for any 421 responses — they indicate either misconfig or probing.
