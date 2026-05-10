# Production Ops Bundle Design

Date: 2026-05-09
Status: Approved for planning

## Summary

Create a new public GitHub-backed repository in `hidden-adventures-scripts` that becomes the canonical source for non-secret production host assets used on the Lightsail VM. The repo will consolidate the runtime scripts and host-managed files currently described inline in `hidden-adventures-plan/workstreams/production-ops-plan.md`, then provide a simple apply workflow that copies those assets into their live host locations.

This repo will not store secrets. Production env files remain server-local and are created and maintained outside git. The repo should be safe to publish publicly.

## Goals

- Put production VM scripts under source control in a dedicated repo.
- Make the production VM able to `git pull` or reclone one repo to stay aligned with the intended host runtime assets.
- Replace plan-doc-only script definitions with real files in this repo.
- Keep the live host paths already defined in the production ops plan.
- Include the public legal/static files served from `/var/www/hidden-adventures/public`.
- Document a clearer CI/CD contract where application repos produce images and this repo defines host runtime assets.

## Non-Goals

- Store production secrets in git.
- Introduce Terraform, Ansible, or a full infrastructure-as-code stack.
- Build a fully idempotent first-boot server bootstrap system.
- Change the underlying runtime topology defined in the production ops plan.

## Recommended Approach

Use an "ops bundle" structure with a simple apply step:

- Keep canonical source files in this repo.
- Copy those files into live host paths with a shell-based `apply.sh`.
- Manually install the staged Caddy config into `/etc/caddy/Caddyfile` because that path requires elevated host access and should remain an explicit operator step.

This approach keeps the repo public-safe and operationally simple while still making the VM reproducible from source control.

## Repository Shape

Top-level files and folders:

- `README.md`
  - primary operator documentation
  - first-time setup notes
  - update/apply/deploy/backup/rollback usage
- `scripts/`
  - `apply.sh`
  - `deploy.sh`
  - `smoke.sh`
  - `backup-postgres.sh`
  - optional small validation helpers if needed
- `runtime/`
  - production `docker-compose.yml`
  - non-secret env example files
- `caddy/`
  - canonical production `Caddyfile`
- `public/`
  - legal/static files copied to `/var/www/hidden-adventures/public`

The repo should avoid unnecessary nesting. The layout should be obvious to an operator cloning it on the VM.

## Live Host Contract

The repo is the source of truth. The VM continues to run from the existing live paths:

- `/opt/hidden-adventures/docker-compose.yml`
- `/opt/hidden-adventures/env/*.env`
- `/opt/hidden-adventures/scripts/*.sh`
- `/var/www/hidden-adventures/public/*`
- `/etc/caddy/Caddyfile`

The apply step copies repo-managed assets into the host-managed locations above. Real env files remain local to the server and are not committed.

## Apply Workflow

`scripts/apply.sh` is the bridge between source control and live host state.

Responsibilities:

- create any required non-secret target directories if missing
- copy the canonical Compose file into `/opt/hidden-adventures`
- copy repo-managed scripts into `/opt/hidden-adventures/scripts`
- copy legal/static files into `/var/www/hidden-adventures/public`
- stage the canonical `Caddyfile` into a repo-defined output path with clear instructions for manual `sudo` installation

Constraints:

- it must not create or overwrite real secret env files
- it should safely overwrite repo-managed non-secret files
- it should not require manual editing of copied scripts after apply
- scripts should read their local configuration from server-local env files already present on the VM

The intended operator flow is:

1. clone or update this repo on the VM
2. create or maintain local env files outside git
3. run `scripts/apply.sh`
4. manually install the staged Caddyfile into `/etc/caddy/Caddyfile`
5. validate and reload Caddy
6. run the copied operational scripts from `/opt/hidden-adventures/scripts`

## Secrets Boundary

This repo is public and must contain non-secrets only.

Allowed:

- example env templates
- non-secret configuration defaults
- file layout documentation

Not allowed:

- production passwords
- AWS secret access keys
- real admin credentials
- checked-in deploy env files with sensitive values

Operational scripts should fail early with clear errors when required local env files or variables are missing.

## Script Design

The first consolidated scripts are:

- `deploy.sh`
  - authenticate Docker to ECR
  - use the host runtime definition in `/opt/hidden-adventures`
  - pull and restart the runtime
- `smoke.sh`
  - run a small production smoke path
  - verify API health and public legal/static pages
- `backup-postgres.sh`
  - create a timestamped `pg_dump`
  - upload the dump to the configured S3 bucket

Each script should:

- be non-interactive
- read required local configuration from host env files
- avoid embedded secrets and one-off host edits
- be simple enough to inspect quickly during incidents

## Production Ops Plan Changes

`../hidden-adventures-plan/workstreams/production-ops-plan.md` should be updated so it no longer instructs operators to hand-create these runtime files from markdown snippets.

The revised plan should describe this repo as:

- the canonical source for production host runtime assets
- the place where deploy/smoke/backup scripts live under source control
- the place where the production Compose file, canonical Caddyfile, and public legal/static payload are maintained

Step language should shift from "create this file on the VM" to "apply the source-controlled asset from the ops repo to the VM".

The plan should still preserve:

- the same host paths
- the same runtime architecture
- the same secret-management boundary
- the same rollback and smoke-check expectations

## CI/CD Contract

The updated operating model should be explicit:

- app repos build and publish immutable container images
- this ops repo defines the host runtime assets that consume those images
- the VM applies both by combining server-local env files with source-controlled runtime files

GitHub Actions should be described as handing exact promoted image references into the host runtime definition managed by this repo, rather than relying on manual host-side file authoring.

## Verification Criteria

This design is implemented successfully when:

- the repo contains the canonical scripts, runtime templates, Caddy config, and public files
- `apply.sh` installs managed assets into the expected host paths without touching secrets
- copied scripts run from the live host paths and read local env configuration successfully
- `production-ops-plan.md` clearly points to this repo-driven workflow
- the top-level `README.md` explains first-time setup and repeat update/apply flows

## Risks And Guardrails

- Public repo risk: avoid leaking sensitive config by committing example files only.
- Drift risk: treat repo-managed host files as overwriteable outputs of `apply.sh`, not hand-edited long-term snowflakes.
- Caddy privilege boundary: keep `/etc/caddy/Caddyfile` installation manual and explicit rather than hiding it inside a script that assumes `sudo`.
- Complexity risk: defer full bootstrap automation until there is real pressure for it.

## Open Assumptions Resolved

- Repo scope: ops bundle, not scripts-only and not full bootstrap automation.
- Deployment pattern: apply copies files into live host locations instead of running directly from the checkout.
- Secrets policy: non-secrets only because the repo will be public.
- Public assets: legal/static site payload belongs in this repo.
- Docs placement: top-level `README.md`.
