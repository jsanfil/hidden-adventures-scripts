#!/bin/sh

set -eu

if [ "${1:-}" = "--help" ]; then
  cat <<'EOF'
Usage: sh scripts/apply.sh

Copies repo-managed production assets into the live host paths:
- /opt/hidden-adventures/docker-compose.yml
- /opt/hidden-adventures/scripts/
- /opt/hidden-adventures/SOPs/
- /var/www/hidden-adventures/public/

Stages the canonical Caddyfile at:
- /opt/hidden-adventures/staged/Caddyfile

This script does not create or overwrite secret env files.
EOF
  exit 0
fi

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
runtime_root="${RUNTIME_ROOT:-/opt/hidden-adventures}"
runtime_scripts_dir="$runtime_root/scripts"
runtime_staged_dir="$runtime_root/staged"
runtime_sops_dir="$runtime_root/SOPs"
public_root="${PUBLIC_ROOT:-/var/www/hidden-adventures/public}"

mkdir -p "$runtime_scripts_dir" "$runtime_staged_dir" "$runtime_sops_dir" "$public_root"

cp "$repo_root/runtime/docker-compose.yml" "$runtime_root/docker-compose.yml"
cp "$repo_root/scripts/deploy.sh" "$runtime_scripts_dir/deploy.sh"
cp "$repo_root/scripts/smoke.sh" "$runtime_scripts_dir/smoke.sh"
cp "$repo_root/scripts/backup-postgres.sh" "$runtime_scripts_dir/backup-postgres.sh"
cp "$repo_root/caddy/Caddyfile" "$runtime_staged_dir/Caddyfile"
cp "$repo_root/SOPs/"*.md "$runtime_sops_dir/"
cp "$repo_root/public/privacy-policy.html" "$public_root/privacy-policy.html"
cp "$repo_root/public/terms-conditions.html" "$public_root/terms-conditions.html"

chmod 755 \
  "$runtime_scripts_dir/deploy.sh" \
  "$runtime_scripts_dir/smoke.sh" \
  "$runtime_scripts_dir/backup-postgres.sh"

cat <<EOF
Applied repo-managed assets.

Next steps:
1. Ensure $runtime_root/env/*.env exists locally on the server.
2. Install $runtime_staged_dir/Caddyfile to /etc/caddy/Caddyfile with sudo if needed.
3. Validate and reload Caddy.
EOF
