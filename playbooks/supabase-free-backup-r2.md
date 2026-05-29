# Playbook — Supabase Free without backups → daily cron to Cloudflare R2

**Severity:** CRITICAL OPERATIONAL (data loss risk for daily-use product).

**Empirically validated:** mitigated against `aglaya-kanban-desk` (commits `be582cd` through `3ae6541`, 27 May 2026). Took 7 incremental commits to land due to R2 token-format gotchas.

---

## Detection

```bash
# 1. Is Supabase used?
grep -rn "@supabase/supabase-js" package.json
# If yes:

# 2. What plan? CANNOT be detected from code. Required user/operator confirmation via
#    Supabase dashboard → Settings → Billing.
echo "Ask operator: Plan: Supabase Free, Pro, Team, or Enterprise?"

# 3. Existing backup workflow?
ls .github/workflows/ 2>/dev/null | grep -i "backup"
# 0 → CRITICAL if plan = Free.
```

If plan = **Free** and no backup workflow → **CRITICAL IMMEDIATE**.

Supabase Free has:
- ❌ No daily backups
- ❌ No PITR (Point-In-Time Recovery)
- ⚠️ Inactivity pause after 7 days
- ⚠️ Recovery best-effort via support (no SLA)

---

## Mitigation — daily pg_dump → Cloudflare R2 native API

### Why Cloudflare R2 over S3/B2

- **10 GB free** (vs S3 5 GB).
- **Zero egress fees** — restore downloads cost nothing.
- **S3-compatible API** OR **Cloudflare Native R2 API** (we'll use Native — see gotcha below).

### Why Native R2 API, not S3-compatible

**Gotcha empirically confirmed (27 May 2026):** Cloudflare R2 issues two distinct token types:

- `cfat_*` tokens → **S3 API ONLY**.
- `cfut_*` tokens → **Native R2 API ONLY**.

If you generate a `cfut_*` token via the dashboard and try to use it with S3-compatible clients (`aws-cli`, `rclone`, `boto3`), you get `HTTP 400` rejections. Conversely, `cfat_*` tokens fail against the Native API.

**This playbook uses Native R2 API + Bearer token** for simplicity. If you prefer S3 compatibility for some other reason, generate `cfat_*` tokens explicitly.

---

## Step-by-step

### 1. Cloudflare R2: create bucket + Native token

Via dashboard:

1. Cloudflare dashboard → R2 → Create bucket → name e.g. `<repo>-backups-prod` → region WEUR (or closest to your DB region for latency on download).
2. R2 → Manage R2 API Tokens → Create token:
   - Permissions: `Object Read & Write`
   - Scope to the specific bucket.
   - Type: Cloudflare API token (Native), NOT S3 access keys.
3. Save the token (shown only once). Format: `cfut_<long string>`.
4. Note your **Account ID** (visible top-right of any Cloudflare page).

### 2. Supabase: get DATABASE_URL

Dashboard → Settings → Database → Connection string → **URI** (not Direct).

Use the **Session Pooler** (port 5432) if your GitHub Actions runner does not have IPv6 — GitHub Actions runners default to IPv4 only as of late 2025. The pooler URL looks like:

```
postgresql://<user>:<password>@aws-1-<region>.pooler.supabase.com:5432/postgres
```

### 3. GitHub Secrets

In repo Settings → Secrets and variables → Actions, add:

- `DATABASE_URL` (the full Session Pooler URI from step 2)
- `R2_BEARER_TOKEN` (the `cfut_*` token from step 1)
- `R2_ACCOUNT_ID` (your Cloudflare account ID)
- `R2_BUCKET` (e.g. `<repo>-backups-prod`)

### 4. Workflow

Create `.github/workflows/db-backup.yml`:

```yaml
name: db-backup
on:
  schedule:
    - cron: '17 3 * * *'   # 03:17 UTC daily, off-peak
  workflow_dispatch:        # manual trigger for testing + on-demand

jobs:
  backup:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - name: Install PostgreSQL 17 client
        run: |
          sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
          wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
          sudo apt-get update
          sudo apt-get install -y postgresql-client-17
          # Verify
          /usr/lib/postgresql/17/bin/pg_dump --version

      - name: pg_dump
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          set -euo pipefail
          TS=$(date -u +%Y%m%dT%H%M%SZ)
          DUMP_FILE="kanban_${TS}.sql.gz"
          /usr/lib/postgresql/17/bin/pg_dump "$DATABASE_URL" \
            --no-owner --no-acl --clean --if-exists \
            | gzip -9 > "${DUMP_FILE}"
          ls -lh "${DUMP_FILE}"
          echo "DUMP_FILE=${DUMP_FILE}" >> "$GITHUB_ENV"

      - name: Upload to Cloudflare R2 (Native API)
        env:
          R2_BEARER_TOKEN: ${{ secrets.R2_BEARER_TOKEN }}
          R2_ACCOUNT_ID: ${{ secrets.R2_ACCOUNT_ID }}
          R2_BUCKET: ${{ secrets.R2_BUCKET }}
        run: |
          set -euo pipefail
          URL="https://api.cloudflare.com/client/v4/accounts/${R2_ACCOUNT_ID}/r2/buckets/${R2_BUCKET}/objects/${DUMP_FILE}"
          curl -sS -X PUT "$URL" \
            -H "Authorization: Bearer ${R2_BEARER_TOKEN}" \
            -H "Content-Type: application/gzip" \
            --data-binary "@${DUMP_FILE}" \
            --fail-with-body
          echo "Uploaded ${DUMP_FILE} to R2 bucket ${R2_BUCKET}"

      - name: Retention — list + prune objects older than 30 days
        env:
          R2_BEARER_TOKEN: ${{ secrets.R2_BEARER_TOKEN }}
          R2_ACCOUNT_ID: ${{ secrets.R2_ACCOUNT_ID }}
          R2_BUCKET: ${{ secrets.R2_BUCKET }}
        run: |
          set -euo pipefail
          LIST_URL="https://api.cloudflare.com/client/v4/accounts/${R2_ACCOUNT_ID}/r2/buckets/${R2_BUCKET}/objects"
          CUTOFF=$(date -u -d "30 days ago" +%Y%m%dT%H%M%SZ)
          curl -sS "$LIST_URL" -H "Authorization: Bearer ${R2_BEARER_TOKEN}" \
            | jq -r '.result.objects[]?.key' \
            | while read -r KEY; do
                # Extract YYYYMMDDTHHMMSSZ from filename like kanban_YYYYMMDDTHHMMSSZ.sql.gz
                TS=$(echo "$KEY" | grep -oE '[0-9]{8}T[0-9]{6}Z' || true)
                if [ -n "$TS" ] && [ "$TS" \< "$CUTOFF" ]; then
                  DEL_URL="https://api.cloudflare.com/client/v4/accounts/${R2_ACCOUNT_ID}/r2/buckets/${R2_BUCKET}/objects/${KEY}"
                  echo "Pruning ${KEY}"
                  curl -sS -X DELETE "$DEL_URL" -H "Authorization: Bearer ${R2_BEARER_TOKEN}" --fail-with-body
                fi
              done

      - name: Notify on failure
        if: failure()
        run: |
          echo "::error::DB backup failed — manual investigation required"
          # TODO: wire to Sentry/Slack when those are configured
```

### 5. Smoke test

In GitHub Actions UI → Actions → `db-backup` → `Run workflow` → `main`. Wait. Expected: green run in ~30-60s.

Verify the object exists in R2:

```bash
curl -sS \
  "https://api.cloudflare.com/client/v4/accounts/${R2_ACCOUNT_ID}/r2/buckets/${R2_BUCKET}/objects" \
  -H "Authorization: Bearer ${R2_BEARER_TOKEN}" | jq '.result.objects[].key'
```

Should list `kanban_<timestamp>.sql.gz`.

### 6. Restore smoke test (locally)

Download via Native API:

```bash
KEY="kanban_<timestamp>.sql.gz"
curl -sS -o "$KEY" \
  "https://api.cloudflare.com/client/v4/accounts/${R2_ACCOUNT_ID}/r2/buckets/${R2_BUCKET}/objects/${KEY}" \
  -H "Authorization: Bearer ${R2_BEARER_TOKEN}"

# Verify gzip integrity
gunzip -t "$KEY"

# Restore into a local Postgres for validation
# (option A — Docker if available)
docker run -d --name pg-restore-test -e POSTGRES_PASSWORD=test -p 5433:5432 postgres:17
sleep 5
gunzip -c "$KEY" | psql postgresql://postgres:test@localhost:5433/postgres

# Verify tables exist + row counts
psql postgresql://postgres:test@localhost:5433/postgres -c "\dt"
psql postgresql://postgres:test@localhost:5433/postgres -c "SELECT COUNT(*) FROM <main-table>;"

# Cleanup
docker rm -f pg-restore-test
rm "$KEY"
```

(option B — `brew install postgresql@17` if Docker is off)

### 7. Document restore procedure

Create `docs/runbooks/db-restore.md`:

```markdown
# DB Restore from R2 Backup

## When to use
- Supabase incident / data loss.
- Accidental `DROP TABLE` or `DELETE WHERE` without WHERE.
- Migration regression.

## Steps
1. Identify the desired backup timestamp from R2 bucket.
2. Download: see playbook step 6 above for `curl` syntax.
3. Restore into a staging Postgres first (NEVER directly to production).
4. Validate row counts + integrity against the expected state.
5. Decide: full restore (drop + recreate) or partial (copy specific tables).
6. Run inside a transaction. Commit only after smoke test passes.
7. Document the incident in `docs/postmortems/<date>-<incident>.md`.

## RTO/RPO
- RPO: up to 24h (daily backup).
- RTO: ~30 minutes for full restore.

## Owner
<your-team / lead-name>
```

---

## Commit message template

```
fix(ops): daily DB backup cron via GitHub Actions → Cloudflare R2 (mitigates B-CRIT-02)

Supabase Free plan → no daily backups, no PITR. Risk: total data loss
upon corruption/deletion/incident for daily-use product. Identified in
Mariana Trench audit, finding ID <ID>.

Quick-win mitigation: pg_dump nightly at 03:17 UTC via GitHub Actions →
upload to Cloudflare R2 (10 GB free, zero egress fees) via Native API.
Retention: 30 days automatic prune.

Restore procedure documented in docs/runbooks/db-restore.md.
Smoke test executed against local Postgres 17: green.

Structural mitigation (Supabase Pro $25/mo with PITR 7d) deferred to
roadmap Phase E.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Long-term — upgrade to Supabase Pro

The cron + R2 setup gives you 24h RPO. If you need PITR (Point-In-Time Recovery, allowing restore to any second within 7 days), upgrade to Supabase Pro ($25/mo). After upgrade:

1. Verify PITR is active in Supabase dashboard.
2. Optionally retire the custom workflow (but consider keeping it as defense-in-depth — Supabase outages do happen).
3. Update `docs/runbooks/db-restore.md` with PITR procedure (faster + finer-grained than dump restore).
