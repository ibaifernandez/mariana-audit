# Playbook — JWT with long TTL and no refresh token

**Severity:** HIGH (amplifier)
**OWASP:** A02:2021 Cryptographic Failures + A07:2021 Identification and Authentication Failures
**Empirically validated:** Detected in `aglaya-kanban-desk` audit, finding B-02 (May 2026). Mitigation pattern below has been deployed in multiple production apps.

---

## Detection

```bash
# 1. Where is the JWT issued and what's its TTL?
grep -rn "jwt.sign\|jsonwebtoken" server/ --include="*.js" --include="*.ts" 2>/dev/null
# Look for the `expiresIn` option. Common bad patterns: '7d', '30d', '90d', no expiresIn at all.

# 2. Is there a refresh-token endpoint?
grep -rn "refresh.token\|/auth/refresh\|refreshToken" server/ --include="*.js" --include="*.ts" 2>/dev/null
# 0 hits → likely no rotation.

# 3. Where does the JWT live on the client?
grep -rn "localStorage.setItem\|localStorage.getItem" client/src/ 2>/dev/null | grep -iE "token|jwt|session|auth"
# localStorage → JWT exfil possible via any XSS.
```

If TTL ≥ 24h AND no refresh-token endpoint AND localStorage storage → **HIGH** amplifier finding (any XSS becomes 7-day session compromise).

---

## Risk narrative

A long-lived JWT is a long-lived attack surface. If at any point an XSS is exploited (even one that's later patched), every JWT that was stolen before the patch remains valid for the rest of its TTL. The window of abuse is the TTL.

Refresh-token rotation flips this: the **access token** is short-lived (5–15 minutes), and a separate **refresh token** is exchanged for new access tokens. Server can revoke the refresh-token chain centrally. A stolen access token expires in minutes; a stolen refresh token can be invalidated.

---

## Mitigation — refresh-token rotation pattern

This is a **significant refactor** of auth. Do not apply without:

1. A dedicated branch.
2. End-to-end tests for the entire auth flow.
3. Migration plan for users with currently-valid long-lived tokens.
4. A documented rollback procedure.

### Server side (Express + JWT example)

```javascript
const ACCESS_TTL = '15m';
const REFRESH_TTL = '7d';

function issueTokens(user) {
  const access = jwt.sign(
    { sub: user.id, role: user.role, orgId: user.orgId },
    process.env.JWT_ACCESS_SECRET,
    { expiresIn: ACCESS_TTL, issuer: 'kanban' }
  );
  const refreshId = crypto.randomUUID();
  const refresh = jwt.sign(
    { sub: user.id, jti: refreshId },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: REFRESH_TTL, issuer: 'kanban' }
  );
  // Persist refresh-token id in DB so server can revoke.
  storeRefreshToken({ jti: refreshId, userId: user.id, expiresAt: Date.now() + 7 * 86400_000, revoked: false });
  return { access, refresh };
}

router.post('/auth/refresh', async (req, res) => {
  // Refresh token preferably in httpOnly cookie, NOT in JSON body if avoidable.
  const refresh = req.cookies.refresh_token;
  if (!refresh) return res.status(401).json({ error: 'no_refresh' });
  try {
    const payload = jwt.verify(refresh, process.env.JWT_REFRESH_SECRET, { issuer: 'kanban' });
    const stored = await getRefreshToken(payload.jti);
    if (!stored || stored.revoked || stored.userId !== payload.sub) {
      return res.status(401).json({ error: 'refresh_invalid' });
    }
    // Rotate: revoke old, issue new pair.
    await revokeRefreshToken(payload.jti);
    const user = await getUserById(payload.sub);
    if (!user) return res.status(401).json({ error: 'user_gone' });
    const tokens = issueTokens(user);
    setRefreshCookie(res, tokens.refresh);
    return res.json({ access: tokens.access });
  } catch (e) {
    return res.status(401).json({ error: 'refresh_invalid' });
  }
});

function setRefreshCookie(res, value) {
  res.cookie('refresh_token', value, {
    httpOnly: true,
    secure: true,
    sameSite: 'lax',
    maxAge: 7 * 86400_000,
    path: '/api/auth/refresh',
  });
}
```

### Client side

- Store **access token in memory** (e.g. a React Context), NOT in `localStorage`. It can be re-fetched via `/auth/refresh` if the page reloads.
- The `/auth/refresh` endpoint uses the refresh-token cookie. The client never sees the refresh token directly.
- On any 401 from a regular API call, the client calls `/auth/refresh` once, retries the original call. If refresh also returns 401, redirect to login.

### Migration

For users currently holding a long-lived JWT:

1. Deploy both refresh-flow AND legacy-acceptance for one rotation period (e.g. one access TTL ≈ one week).
2. On any legacy JWT call, issue a new refresh+access pair as a one-time courtesy migration.
3. After the rotation period, reject legacy JWTs and force re-login.

---

## Regression tests

```javascript
describe('auth refresh flow', () => {
  it('issues access + refresh on login', async () => {
    const res = await request(app).post('/auth/login').send({ email: 'a@b.com', password: 'x' });
    expect(res.body.access).toMatch(/^eyJ/);
    expect(res.headers['set-cookie'].some(c => c.startsWith('refresh_token='))).toBe(true);
  });

  it('refresh issues new access + rotates refresh token', async () => {
    const login = await request(app).post('/auth/login').send({ email: 'a@b.com', password: 'x' });
    const refreshCookie = login.headers['set-cookie'].find(c => c.startsWith('refresh_token='));
    const refresh = await request(app).post('/auth/refresh').set('Cookie', refreshCookie);
    expect(refresh.status).toBe(200);
    expect(refresh.body.access).toMatch(/^eyJ/);
    const newRefreshCookie = refresh.headers['set-cookie'].find(c => c.startsWith('refresh_token='));
    expect(newRefreshCookie).not.toBe(refreshCookie); // rotated
  });

  it('reusing revoked refresh fails', async () => {
    const login = await request(app).post('/auth/login').send({ email: 'a@b.com', password: 'x' });
    const refreshCookie = login.headers['set-cookie'].find(c => c.startsWith('refresh_token='));
    await request(app).post('/auth/refresh').set('Cookie', refreshCookie); // first use rotates
    const second = await request(app).post('/auth/refresh').set('Cookie', refreshCookie);
    expect(second.status).toBe(401); // reuse rejected
  });

  it('access token expires in 15m', () => {
    const token = issueTokens({ id: 'u1', role: 'member', orgId: 'o1' }).access;
    const payload = jwt.decode(token);
    expect(payload.exp - payload.iat).toBeLessThanOrEqual(15 * 60);
  });
});
```

---

## Smoke / verification

```bash
# 1. Login: returns access in body + refresh in cookie
curl -i -X POST https://app.example.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"..."}'

# 2. Use access for a regular API call — should work
curl -i https://app.example.com/api/me -H "Authorization: Bearer <access>"

# 3. After 15m, the access fails 401; the client should /auth/refresh and get new tokens
curl -i -X POST https://app.example.com/auth/refresh --cookie "refresh_token=<value>"

# 4. Reuse of the now-rotated refresh should fail
curl -i -X POST https://app.example.com/auth/refresh --cookie "refresh_token=<old value>"
```

---

## Commit message template

```
feat(auth): refresh-token rotation (mitigates B-02 long-TTL JWT)

Access token TTL reduced from N days to 15 minutes. Added refresh-token
rotation flow stored in httpOnly cookie. Server tracks refresh-token IDs
in DB so revocation is centralized.

Migration: legacy long-lived JWTs accepted for one rotation period
(N days) during which clients are silently upgraded to refresh-flow.

Tests added: server/tests/auth.refresh.test.js (4 cases).

Identified during Mariana Trench audit, finding ID <ID>.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Follow-up hardening

- Move access token from `localStorage` to **memory + httpOnly cookie + CSRF token** for double-submit pattern.
- Add device fingerprinting on refresh-token issuance for additional bot-vs-user signal.
- Rate limit `/auth/refresh` per IP and per user.
