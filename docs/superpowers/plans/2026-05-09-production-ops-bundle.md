# Production Ops Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a public, source-controlled ops bundle repo that owns the production host scripts, runtime templates, Caddy config, and legal/static payload, then update the production ops plan to point at this repo-driven workflow.

**Architecture:** The repo will keep canonical non-secret source files under `scripts/`, `runtime/`, `caddy/`, and `public/`, then use `scripts/apply.sh` to copy managed assets into the existing host paths under `/opt/hidden-adventures` and `/var/www/hidden-adventures/public`. Production secrets stay server-local and untracked, while `../hidden-adventures-plan/workstreams/production-ops-plan.md` is updated to replace inline file-authoring instructions with the new apply-based operating model.

**Tech Stack:** POSIX shell, Docker Compose, Caddy, Markdown documentation, git

---

## File Structure

### Files to Create

- `README.md`
  - top-level operator guide for first-time setup, apply flow, deploy flow, backup flow, rollback flow, and secret boundaries
- `scripts/apply.sh`
  - copies repo-managed assets into live host paths and stages the Caddyfile for manual install
- `scripts/deploy.sh`
  - authenticates to ECR, loads local deploy config, pulls images, and restarts the runtime
- `scripts/smoke.sh`
  - runs production smoke checks for API health and legal/static pages
- `scripts/backup-postgres.sh`
  - creates timestamped Postgres dumps and uploads them to S3
- `runtime/docker-compose.yml`
  - canonical production runtime definition
- `runtime/env/api.env.example`
  - example non-secret API env file template
- `runtime/env/admin.env.example`
  - example non-secret admin env file template
- `runtime/env/postgres.env.example`
  - example Postgres env template with placeholders only
- `runtime/env/deploy.env.example`
  - example deploy metadata env template
- `caddy/Caddyfile`
  - canonical production Caddy config with clear placeholders
- `public/privacy-policy.html`
  - legal/static page payload copied to the host
- `public/terms-conditions.html`
  - legal/static page payload copied to the host

### Files to Modify

- `docs/superpowers/specs/2026-05-09-production-ops-bundle-design.md`
  - no planned modification during implementation unless the implementation exposes a spec bug
- `../hidden-adventures-plan/workstreams/production-ops-plan.md`
  - rewrite the VM setup and runtime asset sections to point at this repo and the apply workflow

### Verification Commands

- `sh scripts/apply.sh --help`
- `sh scripts/smoke.sh` with controlled env overrides where needed
- `sh scripts/backup-postgres.sh` with mocked commands where needed
- `git diff -- ../hidden-adventures-plan/workstreams/production-ops-plan.md`

---

### Task 1: Scaffold The Repo Structure

**Files:**
- Create: `README.md`
- Create: `scripts/apply.sh`
- Create: `scripts/deploy.sh`
- Create: `scripts/smoke.sh`
- Create: `scripts/backup-postgres.sh`
- Create: `runtime/docker-compose.yml`
- Create: `runtime/env/api.env.example`
- Create: `runtime/env/admin.env.example`
- Create: `runtime/env/postgres.env.example`
- Create: `runtime/env/deploy.env.example`
- Create: `caddy/Caddyfile`
- Create: `public/privacy-policy.html`
- Create: `public/terms-conditions.html`

- [ ] **Step 1: Create the directory layout**

Run:

```bash
mkdir -p scripts runtime/env caddy public
```

Expected: `scripts`, `runtime/env`, `caddy`, and `public` now exist in the repo root.

- [ ] **Step 2: Create the top-level README with the operator outline**

Write `README.md` with this initial structure:

```markdown
# Hidden Adventures Production Ops Bundle

This repository is the canonical source for non-secret production host assets used on the Hidden Adventures Lightsail VM.

## What This Repo Owns

- operational scripts copied into `/opt/hidden-adventures/scripts`
- the production Compose file copied into `/opt/hidden-adventures/docker-compose.yml`
- the canonical Caddyfile staged for manual install into `/etc/caddy/Caddyfile`
- legal/static files copied into `/var/www/hidden-adventures/public`

## What This Repo Does Not Own

- production secrets
- real env files under `/opt/hidden-adventures/env`
- direct writes to `/etc/caddy/Caddyfile`

## First-Time VM Setup

1. Clone this repo onto the VM.
2. Create real env files under `/opt/hidden-adventures/env`.
3. Run `sh scripts/apply.sh`.
4. Copy the staged Caddyfile into `/etc/caddy/Caddyfile` with `sudo`.
5. Validate and reload Caddy.

## Routine Update Flow

1. `git pull`
2. `sh scripts/apply.sh`
3. Reinstall Caddy if the staged config changed.
4. Run smoke checks.
```

- [ ] **Step 3: Create the placeholder public files so the repo shape is complete**

Write `public/privacy-policy.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Hidden Adventures Privacy Policy</title>
  </head>
  <body>
    <h1>Privacy Policy</h1>
    <p>Replace this placeholder with the production legal page content.</p>
  </body>
</html>
```

Write `public/terms-conditions.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Hidden Adventures Terms &amp; Conditions</title>
  </head>
  <body>
    <h1>Terms &amp; Conditions</h1>
    <p>Replace this placeholder with the production legal page content.</p>
  </body>
</html>
```

- [ ] **Step 4: Commit the scaffold**

Run:

```bash
git add README.md scripts runtime caddy public
git commit -m "feat: scaffold production ops bundle"
```

Expected: commit succeeds and the repo now has the canonical directory structure.

---

### Task 2: Add The Canonical Runtime And Env Templates

**Files:**
- Create: `runtime/docker-compose.yml`
- Create: `runtime/env/api.env.example`
- Create: `runtime/env/admin.env.example`
- Create: `runtime/env/postgres.env.example`
- Create: `runtime/env/deploy.env.example`

- [ ] **Step 1: Write the production Compose file**

Write `runtime/docker-compose.yml`:

```yaml
services:
  api:
    image: ${API_IMAGE}
    restart: unless-stopped
    env_file:
      - ./env/api.env
    ports:
      - "127.0.0.1:3000:3000"
    depends_on:
      - postgres

  admin:
    image: ${ADMIN_IMAGE}
    restart: unless-stopped
    env_file:
      - ./env/admin.env
    ports:
      - "127.0.0.1:3001:3000"
    depends_on:
      - postgres

  postgres:
    image: postgis/postgis:16-3.4
    restart: unless-stopped
    env_file:
      - ./env/postgres.env
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

- [ ] **Step 2: Write the example runtime env templates**

Write `runtime/env/postgres.env.example`:

```dotenv
POSTGRES_DB=hidden_adventures
POSTGRES_USER=hidden_adventures
POSTGRES_PASSWORD=replace-on-server
```

Write `runtime/env/deploy.env.example`:

```dotenv
AWS_REGION=us-west-2
ECR_REGISTRY=replace-me.dkr.ecr.us-west-2.amazonaws.com
API_IMAGE=replace-me.dkr.ecr.us-west-2.amazonaws.com/hidden-adventures-api:replace-me
ADMIN_IMAGE=replace-me.dkr.ecr.us-west-2.amazonaws.com/hidden-adventures-admin:replace-me
S3_BACKUP_BUCKET=replace-me
```

Write `runtime/env/api.env.example`:

```dotenv
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=hidden_adventures
POSTGRES_USER=hidden_adventures
POSTGRES_PASSWORD=replace-on-server
AWS_REGION=us-west-2
S3_BUCKET=replace-me
COGNITO_USER_POOL_ID=replace-me
COGNITO_CLIENT_ID=replace-me
```

Write `runtime/env/admin.env.example`:

```dotenv
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
API_BASE_URL=https://hiddenadventures.lucidios.com
```

- [ ] **Step 3: Verify the Compose template is internally consistent**

Run:

```bash
sed -n '1,220p' runtime/docker-compose.yml
sed -n '1,220p' runtime/env/deploy.env.example
```

Expected: the compose file references `API_IMAGE`, `ADMIN_IMAGE`, and `./env/*.env` exactly as documented in the env templates.

- [ ] **Step 4: Commit the runtime templates**

Run:

```bash
git add runtime
git commit -m "feat: add production runtime templates"
```

Expected: commit succeeds with the Compose file and example env files staged.

---

### Task 3: Implement The Caddy Config And Apply Script

**Files:**
- Create: `caddy/Caddyfile`
- Create: `scripts/apply.sh`

- [ ] **Step 1: Write the canonical Caddyfile**

Write `caddy/Caddyfile`:

```caddy
hiddenadventures.lucidios.com {
    encode gzip

    root * /var/www/hidden-adventures

    handle /api/* {
        reverse_proxy 127.0.0.1:3000
    }

    handle /public/* {
        file_server
    }

    handle {
        file_server
    }
}

admin-adventures.lucidios.com {
    encode gzip

    basicauth {
        joe REPLACE_WITH_REAL_HASH
    }

    reverse_proxy 127.0.0.1:3001
}
```

- [ ] **Step 2: Write the apply script**

Write `scripts/apply.sh`:

```sh
#!/bin/sh

set -eu

if [ "${1:-}" = "--help" ]; then
  cat <<'EOF'
Usage: sh scripts/apply.sh

Copies repo-managed production assets into the live host paths:
- /opt/hidden-adventures/docker-compose.yml
- /opt/hidden-adventures/scripts/
- /var/www/hidden-adventures/public/

Stages the canonical Caddyfile at:
- /opt/hidden-adventures/staged/Caddyfile

This script does not create or overwrite secret env files.
EOF
  exit 0
fi

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
runtime_root="/opt/hidden-adventures"
runtime_scripts_dir="$runtime_root/scripts"
runtime_staged_dir="$runtime_root/staged"
public_root="/var/www/hidden-adventures/public"

mkdir -p "$runtime_scripts_dir" "$runtime_staged_dir" "$public_root"

cp "$repo_root/runtime/docker-compose.yml" "$runtime_root/docker-compose.yml"
cp "$repo_root/scripts/deploy.sh" "$runtime_scripts_dir/deploy.sh"
cp "$repo_root/scripts/smoke.sh" "$runtime_scripts_dir/smoke.sh"
cp "$repo_root/scripts/backup-postgres.sh" "$runtime_scripts_dir/backup-postgres.sh"
cp "$repo_root/caddy/Caddyfile" "$runtime_staged_dir/Caddyfile"
cp "$repo_root/public/privacy-policy.html" "$public_root/privacy-policy.html"
cp "$repo_root/public/terms-conditions.html" "$public_root/terms-conditions.html"

chmod 755 \
  "$runtime_scripts_dir/deploy.sh" \
  "$runtime_scripts_dir/smoke.sh" \
  "$runtime_scripts_dir/backup-postgres.sh"

cat <<EOF
Applied repo-managed assets.

Next steps:
1. Ensure /opt/hidden-adventures/env/*.env exists locally on the server.
2. Install /opt/hidden-adventures/staged/Caddyfile to /etc/caddy/Caddyfile with sudo if needed.
3. Validate and reload Caddy.
EOF
```

- [ ] **Step 3: Verify the apply script help output**

Run:

```bash
sh scripts/apply.sh --help
```

Expected: usage text prints and the command exits successfully without attempting host writes.

- [ ] **Step 4: Commit the apply flow**

Run:

```bash
git add caddy/Caddyfile scripts/apply.sh
git commit -m "feat: add caddy config and apply script"
```

Expected: commit succeeds and the repo now contains the canonical apply workflow.

---

### Task 4: Implement The Deploy, Smoke, And Backup Scripts

**Files:**
- Create: `scripts/deploy.sh`
- Create: `scripts/smoke.sh`
- Create: `scripts/backup-postgres.sh`

- [ ] **Step 1: Write the deploy script**

Write `scripts/deploy.sh`:

```sh
#!/bin/sh

set -eu

runtime_root="/opt/hidden-adventures"
deploy_env="$runtime_root/env/deploy.env"

if [ ! -f "$deploy_env" ]; then
  echo "Missing $deploy_env" >&2
  exit 1
fi

. "$deploy_env"

: "${AWS_REGION:?Missing AWS_REGION in $deploy_env}"
: "${ECR_REGISTRY:?Missing ECR_REGISTRY in $deploy_env}"
: "${API_IMAGE:?Missing API_IMAGE in $deploy_env}"
: "${ADMIN_IMAGE:?Missing ADMIN_IMAGE in $deploy_env}"

cd "$runtime_root"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker compose pull api admin
docker compose up -d
docker compose ps
```

- [ ] **Step 2: Write the smoke script**

Write `scripts/smoke.sh`:

```sh
#!/bin/sh

set -eu

BASE_URL="${BASE_URL:-https://hiddenadventures.lucidios.com}"

curl -fsS "$BASE_URL/api/health" >/dev/null
curl -fsS "$BASE_URL/public/privacy-policy.html" >/dev/null
curl -fsS "$BASE_URL/public/terms-conditions.html" >/dev/null

echo "Production smoke checks passed for $BASE_URL"
```

- [ ] **Step 3: Write the backup script**

Write `scripts/backup-postgres.sh`:

```sh
#!/bin/sh

set -eu

runtime_root="/opt/hidden-adventures"
postgres_env="$runtime_root/env/postgres.env"
deploy_env="$runtime_root/env/deploy.env"

if [ ! -f "$postgres_env" ]; then
  echo "Missing $postgres_env" >&2
  exit 1
fi

if [ ! -f "$deploy_env" ]; then
  echo "Missing $deploy_env" >&2
  exit 1
fi

. "$postgres_env"
. "$deploy_env"

: "${POSTGRES_USER:?Missing POSTGRES_USER in $postgres_env}"
: "${POSTGRES_DB:?Missing POSTGRES_DB in $postgres_env}"
: "${S3_BACKUP_BUCKET:?Missing S3_BACKUP_BUCKET in $deploy_env}"

timestamp="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
backup_dir="$runtime_root/backups"
backup_file="$backup_dir/db_$timestamp.dump"

mkdir -p "$backup_dir"

cd "$runtime_root"

docker compose exec -T postgres \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "$backup_file"

aws s3 cp "$backup_file" "s3://$S3_BACKUP_BUCKET/postgres/"

echo "Backup written to $backup_file and uploaded to s3://$S3_BACKUP_BUCKET/postgres/"
```

- [ ] **Step 4: Verify missing-env failures are clear**

Run:

```bash
sh scripts/deploy.sh
sh scripts/backup-postgres.sh
```

Expected:

- `sh scripts/deploy.sh` fails with `Missing /opt/hidden-adventures/env/deploy.env`
- `sh scripts/backup-postgres.sh` fails with `Missing /opt/hidden-adventures/env/postgres.env` or `Missing /opt/hidden-adventures/env/deploy.env`

- [ ] **Step 5: Commit the operational scripts**

Run:

```bash
git add scripts/deploy.sh scripts/smoke.sh scripts/backup-postgres.sh
git commit -m "feat: add production operational scripts"
```

Expected: commit succeeds with the three executable production scripts staged.

---

### Task 5: Finish The README And Operator Guidance

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Expand the README into the complete operator guide**

Replace `README.md` with:

```markdown
# Hidden Adventures Production Ops Bundle

This repository is the canonical source for non-secret production host assets used on the Hidden Adventures Lightsail VM.

## Repository Layout

- `scripts/`: apply, deploy, smoke, and backup scripts
- `runtime/`: production Compose file and example env templates
- `caddy/`: canonical production Caddyfile
- `public/`: legal/static files copied to the production host

## Secret Boundary

This repository is safe to publish publicly because it contains non-secret files only.

Do not commit:

- real `/opt/hidden-adventures/env/*.env` files
- production passwords
- AWS secret access keys
- real admin credentials

## First-Time VM Setup

1. Clone this repository onto the production VM.
2. Install host packages and create the base host directories described in the production ops plan.
3. Create real env files under `/opt/hidden-adventures/env/`:
   - `api.env`
   - `admin.env`
   - `postgres.env`
   - `deploy.env`
4. Run `sh scripts/apply.sh`.
5. Copy `/opt/hidden-adventures/staged/Caddyfile` to `/etc/caddy/Caddyfile` with `sudo`.
6. Run `sudo caddy validate --config /etc/caddy/Caddyfile`.
7. Run `sudo systemctl reload caddy`.

## Routine Update Flow

1. Pull the latest version of this repo.
2. Run `sh scripts/apply.sh`.
3. Reinstall the staged Caddyfile if it changed.
4. Run the operational scripts from `/opt/hidden-adventures/scripts/` as needed.

## Operational Scripts

### Deploy

Run:

```bash
sh /opt/hidden-adventures/scripts/deploy.sh
```

Requires:

- `/opt/hidden-adventures/env/deploy.env`
- Docker, Docker Compose, and AWS CLI installed on the host

### Smoke

Run:

```bash
sh /opt/hidden-adventures/scripts/smoke.sh
```

Optional override:

```bash
BASE_URL=https://hiddenadventures.lucidios.com \
sh /opt/hidden-adventures/scripts/smoke.sh
```

### Backup

Run:

```bash
sh /opt/hidden-adventures/scripts/backup-postgres.sh
```

Requires:

- `/opt/hidden-adventures/env/postgres.env`
- `/opt/hidden-adventures/env/deploy.env`

## Related Planning Doc

The broader production operating model is documented in:

- `../hidden-adventures-plan/workstreams/production-ops-plan.md`
```

- [ ] **Step 2: Review the README for consistency with the spec**

Run:

```bash
sed -n '1,260p' README.md
```

Expected: the README matches the approved design for repo scope, apply flow, and public-repo secret boundaries.

- [ ] **Step 3: Commit the README**

Run:

```bash
git add README.md
git commit -m "docs: add production ops bundle guide"
```

Expected: commit succeeds with the top-level operator docs staged.

---

### Task 6: Rewrite The Production Ops Plan Around The Repo-Driven Workflow

**Files:**
- Modify: `../hidden-adventures-plan/workstreams/production-ops-plan.md`

- [ ] **Step 1: Replace the directory-layout step to reference the repo bundle**

Update the host layout section so it keeps:

```markdown
- `/opt/hidden-adventures`
- `/opt/hidden-adventures/env`
- `/opt/hidden-adventures/scripts`
- `/opt/hidden-adventures/backups`
- `/var/www/hidden-adventures/public`
```

And add language that the scripts, Compose file, staged Caddyfile, and public files are applied from the public `hidden-adventures-scripts` repo rather than hand-authored on the VM.

- [ ] **Step 2: Replace inline file-creation sections with repo-driven instructions**

Rewrite the sections that currently say:

- create `/etc/caddy/Caddyfile`
- create `/opt/hidden-adventures/docker-compose.yml`
- create `/opt/hidden-adventures/scripts/deploy.sh`
- create `/opt/hidden-adventures/scripts/smoke.sh`
- create `/opt/hidden-adventures/scripts/backup-postgres.sh`

So they instead describe:

```markdown
1. clone or update the public ops repo on the VM
2. run `sh scripts/apply.sh`
3. copy `/opt/hidden-adventures/staged/Caddyfile` into `/etc/caddy/Caddyfile` with `sudo`
4. validate and reload Caddy
5. run the copied scripts from `/opt/hidden-adventures/scripts`
```

- [ ] **Step 3: Tighten the CI/CD handoff language**

Update the CI/CD phase so it explicitly says:

```markdown
- application repos build and publish immutable images
- this ops repo defines the host runtime files that reference those images
- production deploys update the host runtime definition by changing server-local env values and then running the copied deploy script
```

- [ ] **Step 4: Review the production ops plan diff**

Run:

```bash
git -C ../hidden-adventures-plan diff -- workstreams/production-ops-plan.md
```

Expected: the plan preserves the existing architecture and host paths, but no longer tells operators to manually author runtime assets from markdown snippets.

- [ ] **Step 5: Commit the plan-doc change in the plan repo**

Run:

```bash
git -C ../hidden-adventures-plan add workstreams/production-ops-plan.md
git -C ../hidden-adventures-plan commit -m "docs: point production ops plan at ops bundle repo"
```

Expected: commit succeeds in the `hidden-adventures-plan` repo with only the ops-plan doc updated.

---

### Task 7: Final Verification And Cleanup

**Files:**
- Verify: `README.md`
- Verify: `scripts/apply.sh`
- Verify: `scripts/deploy.sh`
- Verify: `scripts/smoke.sh`
- Verify: `scripts/backup-postgres.sh`
- Verify: `runtime/docker-compose.yml`
- Verify: `caddy/Caddyfile`
- Verify: `../hidden-adventures-plan/workstreams/production-ops-plan.md`

- [ ] **Step 1: Review the final repo tree**

Run:

```bash
find . -maxdepth 3 -type f | sort
```

Expected: the repo contains `README.md`, `scripts/*`, `runtime/*`, `caddy/Caddyfile`, `public/*`, and the saved spec/plan docs.

- [ ] **Step 2: Run the safe local verification commands**

Run:

```bash
sh scripts/apply.sh --help
sh scripts/deploy.sh
sh scripts/backup-postgres.sh
BASE_URL=https://hiddenadventures.lucidios.com sh scripts/smoke.sh
```

Expected:

- `sh scripts/apply.sh --help` succeeds
- `sh scripts/deploy.sh` fails fast on missing local env if not on the VM
- `sh scripts/backup-postgres.sh` fails fast on missing local env if not on the VM
- `sh scripts/smoke.sh` either passes against the live URL or fails with a real network or endpoint error that should be documented before release

- [ ] **Step 3: Review git status in both repos**

Run:

```bash
git status --short
git -C ../hidden-adventures-plan status --short
```

Expected: both repos are clean after the planned commits.

- [ ] **Step 4: Record any follow-up gaps discovered during verification**

If verification exposes gaps, document them explicitly in the relevant commit message or as a follow-up note before publishing the new repo.

- [ ] **Step 5: Prepare the repo for GitHub publication**

Run:

```bash
git log --oneline --decorate -5
```

Expected: the repo history shows a small sequence of focused commits suitable for first push to GitHub.

---

## Self-Review

### Spec Coverage

- Repo shape: covered by Tasks 1, 2, 3, and 5.
- Apply workflow: covered by Task 3 and verified in Task 7.
- Non-secret public-repo boundary: covered by Tasks 2, 4, 5, and 6.
- Operational scripts: covered by Task 4.
- Public legal/static payload: covered by Task 1 and Task 3.
- Production ops plan rewrite: covered by Task 6.
- CI/CD contract clarification: covered by Task 6 Step 3.

### Placeholder Scan

- The only intentional placeholders are safe public placeholders such as `replace-me` and `REPLACE_WITH_REAL_HASH` inside example files and the canonical Caddyfile.
- No task contains `TODO`, `TBD`, or “implement later” language.

### Type Consistency

- Host paths are consistent across tasks: `/opt/hidden-adventures`, `/opt/hidden-adventures/env`, `/opt/hidden-adventures/scripts`, `/var/www/hidden-adventures/public`.
- Deploy metadata uses `deploy.env` consistently across scripts, README, and plan-doc updates.
- The smoke script consistently uses `BASE_URL` and checks the same three endpoints throughout the plan.
