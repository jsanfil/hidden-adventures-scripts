# Hidden Adventures Production Ops Bundle

This repository is the canonical source for non-secret production host assets used on the Hidden Adventures Lightsail VM.

The production operator boundary is split in two:

- laptop operator entrypoint: `scripts/release-api.sh`
- VM runtime scripts: `/opt/hidden-adventures/scripts/deploy.sh`, `/opt/hidden-adventures/scripts/smoke.sh`, and `/opt/hidden-adventures/scripts/backup-postgres.sh`

## Repository Layout

- `scripts/`: local release script plus VM apply, deploy, smoke, and backup scripts
- `runtime/`: production Compose file and example env templates
- `caddy/`: canonical production Caddyfile
- `public/`: legal/static files copied to the production host
- `SOPs/`: operator procedures copied to the production host

## Secret Boundary

This repository is safe to publish publicly because it contains non-secret files only.

Do not commit:

- real `/opt/hidden-adventures/env/*.env` files
- production passwords
- AWS secret access keys
- real application credentials

Also do not commit:

- `.env.production.local`

## First-Time VM Setup

1. Clone this repository onto the production VM.
2. Install host packages and create the base host directories described in the production ops plan.
3. Create real env files under `/opt/hidden-adventures/env/`:
   - `api.env`
   - `postgres.env`
   - `deploy.env`
4. Run `sh scripts/apply.sh`.
5. Copy `/opt/hidden-adventures/staged/Caddyfile` to `/etc/caddy/Caddyfile` with `sudo`.
6. Run `sudo caddy validate --config /etc/caddy/Caddyfile`.
7. Run `sudo systemctl reload caddy`.
8. From your laptop checkout of this repo, create `.env.production.local` for release automation.

## Routine Update Flow

1. Pull the latest version of this repo.
2. Run `sh scripts/apply.sh`.
3. Reinstall the staged Caddyfile if it changed.
4. Run `sh scripts/release-api.sh` from your laptop when you need to push, deploy, ship, or rollback an API image.
5. Run the operational scripts from `/opt/hidden-adventures/scripts/` on the VM as needed.

## Laptop Release Script

Run from your laptop checkout of `hidden-adventures-scripts`:

```bash
sh scripts/release-api.sh --help
```

The script reads local operator config from `.env.production.local`, builds the API image from `hidden-adventures-server`, pushes it to ECR, and SSHes to the VM for deploy and rollback actions.

## VM Operational Scripts

### Deploy

Run:

```bash
sh /opt/hidden-adventures/scripts/deploy.sh
```

Requires:

- `/opt/hidden-adventures/env/deploy.env`
- `/opt/hidden-adventures/env/api.env`
- `/opt/hidden-adventures/env/postgres.env`
- Docker, Docker Compose, and AWS CLI installed on the host

This script is run on the VM, usually by `scripts/release-api.sh` over SSH.

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

This script is run on the VM, usually by `scripts/release-api.sh` after deploy.

### Backup

Run:

```bash
sh /opt/hidden-adventures/scripts/backup-postgres.sh
```

Requires:

- `/opt/hidden-adventures/env/postgres.env`
- `/opt/hidden-adventures/env/deploy.env`

## SOPs

The repo includes operator runbooks under `SOPs/`, and `scripts/apply.sh` copies them to `/opt/hidden-adventures/SOPs/` on the VM.

## Related Planning Doc

The broader production operating model is documented in:

- `../hidden-adventures-plan/workstreams/production-ops-plan.md`
