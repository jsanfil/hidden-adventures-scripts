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
