#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
script_path="$repo_root/scripts/release-api.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT INT TERM HUP

bin_dir="$tmp_dir/bin"
server_repo="$tmp_dir/server"
mkdir -p "$bin_dir" "$server_repo"

cat >"$bin_dir/git" <<'EOF'
#!/bin/sh
case "$1" in
  rev-parse)
    if [ "${2:-}" = "--show-toplevel" ]; then
      pwd
      exit 0
    fi
    if [ "${2:-}" = "HEAD" ]; then
      printf '%s\n' "0123456789abcdef0123456789abcdef01234567"
      exit 0
    fi
    if [ "${2:-}" = "--short" ] && [ "${3:-}" = "HEAD" ]; then
      printf '%s\n' "0123456"
      exit 0
    fi
    ;;
esac
printf '%s\n' "unexpected git args: $*" >&2
exit 1
EOF

cat >"$bin_dir/docker" <<'EOF'
#!/bin/sh
printf 'docker %s\n' "$*" >>"$TEST_LOG"
if [ "$1" = "image" ] && [ "$2" = "inspect" ]; then
  printf '%s\n' "0123456789.dkr.ecr.us-west-2.amazonaws.com/hidden-adventures-api@sha256:feedface"
fi
EOF

cat >"$bin_dir/aws" <<'EOF'
#!/bin/sh
printf 'aws %s\n' "$*" >>"$TEST_LOG"
if [ "$1" = "ecr" ] && [ "$2" = "get-login-password" ]; then
  printf '%s\n' "token"
fi
EOF

cat >"$bin_dir/ssh" <<'EOF'
#!/bin/sh
printf 'ssh %s\n' "$*" >>"$TEST_LOG"
EOF

chmod 755 "$bin_dir/git" "$bin_dir/docker" "$bin_dir/aws" "$bin_dir/ssh"

cat >"$server_repo/Dockerfile.deploy" <<'EOF'
FROM scratch
EOF

cat >"$server_repo/package.json" <<'EOF'
{}
EOF

test_log="$tmp_dir/test.log"
: >"$test_log"

env_file="$tmp_dir/.env.production.local"
cat >"$env_file" <<EOF
SERVER_REPO_DIR=$server_repo
AWS_REGION=us-west-2
ECR_REGISTRY=0123456789.dkr.ecr.us-west-2.amazonaws.com
ECR_REPOSITORY_API=hidden-adventures-api
PRODUCTION_SSH_HOST=example.com
PRODUCTION_SSH_USER=ubuntu
PRODUCTION_RUNTIME_ROOT=/opt/hidden-adventures
SMOKE_BASE_URL=https://hiddenadventures.lucidios.com
EOF

export PATH="$bin_dir:$PATH"
export TEST_LOG="$test_log"

help_output="$tmp_dir/help.txt"
push_output="$tmp_dir/push.txt"
deploy_output="$tmp_dir/deploy.txt"
rollback_output="$tmp_dir/rollback.txt"

sh "$script_path" --help >"$help_output"
grep -q "Local laptop steps" "$help_output"
grep -q "VM steps over SSH" "$help_output"

RELEASE_ENV_FILE="$env_file" sh "$script_path" push --dry-run >"$push_output"
grep -q "docker build" "$push_output"
grep -q "docker push" "$push_output"
grep -q "@sha256:<digest>" "$push_output"

image_ref="0123456789.dkr.ecr.us-west-2.amazonaws.com/hidden-adventures-api@sha256:feedface"
RELEASE_ENV_FILE="$env_file" sh "$script_path" deploy --dry-run "$image_ref" >"$deploy_output"
grep -q "ssh ubuntu@example.com" "$deploy_output"
grep -q "/opt/hidden-adventures/env/deploy.env" "$deploy_output"
grep -q "/opt/hidden-adventures/scripts/deploy.sh" "$deploy_output"
grep -q "/opt/hidden-adventures/scripts/smoke.sh" "$deploy_output"

RELEASE_ENV_FILE="$env_file" sh "$script_path" rollback --dry-run "$image_ref" >"$rollback_output"
grep -q "rollback" "$rollback_output"
grep -q "$image_ref" "$rollback_output"

echo "release-api tests passed"
