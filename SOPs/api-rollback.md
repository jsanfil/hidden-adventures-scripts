# API Rollback SOP

## When to use this

Use this SOP when the current production API image is unhealthy and you need to restore a previously known-good immutable image ref.

## Operator boundary

- Run `scripts/release-api.sh rollback <image-ref>` from your laptop inside the `hidden-adventures-scripts` repo.
- The script SSHes to the Lightsail VM and triggers `/opt/hidden-adventures/scripts/deploy.sh` and `/opt/hidden-adventures/scripts/smoke.sh` there.

## Required local config

The laptop operator config lives at `.env.production.local` in the repo root. It must contain the same variables used for release:

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

Show the remote rollback steps without changing production:

```bash
sh scripts/release-api.sh rollback --dry-run <image-ref>
```

Perform the rollback:

```bash
sh scripts/release-api.sh rollback <image-ref>
```

## Expected success signals

- rollback completes without SSH, migration, or smoke-check errors
- `/opt/hidden-adventures/env/deploy.env` shows the requested `API_IMAGE`
- `/opt/hidden-adventures/deploy-log.jsonl` contains a new `rollback` entry
- `docker compose ps` on the VM shows healthy `postgres` and `api` containers

## Stop conditions

- you do not have a known-good immutable image ref
- SSH to the VM fails
- migrations fail
- smoke checks fail after rollback

If the rollback deploys successfully but smoke still fails, stop and investigate before attempting another image change.

## Where to inspect state

- Current image ref: `/opt/hidden-adventures/env/deploy.env`
- Deploy history: `/opt/hidden-adventures/deploy-log.jsonl`
- VM deploy script: `/opt/hidden-adventures/scripts/deploy.sh`
- VM smoke script: `/opt/hidden-adventures/scripts/smoke.sh`
