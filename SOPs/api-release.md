# API Release SOP

## When to use this

Use this SOP when you want to push a new Hidden Adventures API image from your laptop and deploy it to the production Lightsail VM.

## Operator boundary

- Run `scripts/release-api.sh` from your laptop inside the `hidden-adventures-scripts` repo.
- The script SSHes to the Lightsail VM and triggers `/opt/hidden-adventures/scripts/deploy.sh` and `/opt/hidden-adventures/scripts/smoke.sh` there.

## Required local config

Create an uncommitted file at `.env.production.local` in the repo root with:

```dotenv
SERVER_REPO_DIR=/Users/josephsanfilippo/Documents/projects/hidden-adventures-rebuild/hidden-adventures-server
AWS_REGION=us-west-2
ECR_REGISTRY=replace-me.dkr.ecr.us-west-2.amazonaws.com
ECR_REPOSITORY_API=hidden-adventures-api
PRODUCTION_SSH_HOST=replace-me
PRODUCTION_SSH_USER=ubuntu
PRODUCTION_RUNTIME_ROOT=/opt/hidden-adventures
SMOKE_BASE_URL=https://hiddenadventures.lucidios.com
```

## Commands

Validate local config and show the planned push steps:

```bash
sh scripts/release-api.sh push --dry-run
```

Push the image and print the immutable image ref:

```bash
sh scripts/release-api.sh push
```

Push and deploy in one command:

```bash
sh scripts/release-api.sh ship
```

Deploy a specific immutable image ref:

```bash
sh scripts/release-api.sh deploy <image-ref>
```

## Expected success signals

- `push` prints an immutable image ref ending in `@sha256:...`
- `ship` or `deploy` completes without SSH, migration, or smoke-check errors
- `docker compose ps` on the VM shows `postgres` and `api`
- `/opt/hidden-adventures/deploy-log.jsonl` contains a new entry with the deployed image ref

## Stop conditions

- `push` fails to build or push the image
- SSH to the VM fails
- migrations fail inside `/opt/hidden-adventures/scripts/deploy.sh`
- smoke checks fail against `https://hiddenadventures.lucidios.com`

Do not keep improvising on the VM if one of those happens. Stop, inspect the deploy log, and diagnose the failing step first.

## Where to inspect state

- Active production image: `/opt/hidden-adventures/env/deploy.env`
- Deploy log: `/opt/hidden-adventures/deploy-log.jsonl`
- VM deploy script: `/opt/hidden-adventures/scripts/deploy.sh`
- VM smoke script: `/opt/hidden-adventures/scripts/smoke.sh`
