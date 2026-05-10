#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
default_env_file="$repo_root/.env.production.local"

usage() {
  cat <<EOF
Usage: sh scripts/release-api.sh <command> [--dry-run] [args]

Commands:
  push [--dry-run]
  deploy [--dry-run] <image-ref>
  ship [--dry-run]
  rollback [--dry-run] <image-ref>
  --help

Local laptop steps:
  - load operator config from ${RELEASE_ENV_FILE:-$default_env_file}
  - validate git, docker, aws, and ssh
  - build the API image from \$SERVER_REPO_DIR/Dockerfile.deploy
  - push mutable tags to ECR
  - resolve and print the immutable image ref

VM steps over SSH:
  - update \$PRODUCTION_RUNTIME_ROOT/env/deploy.env with API_IMAGE
  - run \$PRODUCTION_RUNTIME_ROOT/scripts/deploy.sh
  - run \$PRODUCTION_RUNTIME_ROOT/scripts/smoke.sh
  - append a deploy entry to \$PRODUCTION_RUNTIME_ROOT/deploy-log.jsonl

Required env vars in .env.production.local:
  SERVER_REPO_DIR
  AWS_REGION
  ECR_REGISTRY
  ECR_REPOSITORY_API
  PRODUCTION_SSH_HOST
  PRODUCTION_SSH_USER

Optional env vars:
  PRODUCTION_RUNTIME_ROOT (default: /opt/hidden-adventures)
  SMOKE_BASE_URL (default: https://hiddenadventures.lucidios.com)
  SSH_OPTS
EOF
}

command_name="${1:-}"
if [ -z "$command_name" ] || [ "$command_name" = "--help" ]; then
  usage
  exit 0
fi
shift

dry_run=0
if [ "${1:-}" = "--dry-run" ]; then
  dry_run=1
  shift
fi

env_file="${RELEASE_ENV_FILE:-$default_env_file}"

load_env() {
  if [ ! -f "$env_file" ]; then
    echo "Missing operator env file: $env_file" >&2
    exit 1
  fi

  . "$env_file"

  : "${SERVER_REPO_DIR:?Missing SERVER_REPO_DIR in $env_file}"
  : "${AWS_REGION:?Missing AWS_REGION in $env_file}"
  : "${ECR_REGISTRY:?Missing ECR_REGISTRY in $env_file}"
  : "${ECR_REPOSITORY_API:?Missing ECR_REPOSITORY_API in $env_file}"
  : "${PRODUCTION_SSH_HOST:?Missing PRODUCTION_SSH_HOST in $env_file}"
  : "${PRODUCTION_SSH_USER:?Missing PRODUCTION_SSH_USER in $env_file}"

  PRODUCTION_RUNTIME_ROOT="${PRODUCTION_RUNTIME_ROOT:-/opt/hidden-adventures}"
  SMOKE_BASE_URL="${SMOKE_BASE_URL:-https://hiddenadventures.lucidios.com}"
  SSH_OPTS="${SSH_OPTS:-}"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

validate_local_state() {
  require_command git
  require_command docker
  require_command aws
  require_command ssh

  if [ ! -d "$SERVER_REPO_DIR" ]; then
    echo "SERVER_REPO_DIR does not exist: $SERVER_REPO_DIR" >&2
    exit 1
  fi

  if [ ! -f "$SERVER_REPO_DIR/Dockerfile.deploy" ]; then
    echo "Missing Dockerfile.deploy in $SERVER_REPO_DIR" >&2
    exit 1
  fi

  (
    cd "$SERVER_REPO_DIR"
    git rev-parse --show-toplevel >/dev/null 2>&1
    git rev-parse HEAD >/dev/null 2>&1
    git rev-parse --short HEAD >/dev/null 2>&1
  ) || {
    echo "SERVER_REPO_DIR must be a readable git checkout: $SERVER_REPO_DIR" >&2
    exit 1
  }
}

git_sha() {
  (cd "$SERVER_REPO_DIR" && git rev-parse HEAD)
}

short_sha() {
  (cd "$SERVER_REPO_DIR" && git rev-parse --short HEAD)
}

utc_stamp() {
  date -u +"%Y%m%d%H%M%S"
}

image_repo() {
  printf '%s/%s\n' "$ECR_REGISTRY" "$ECR_REPOSITORY_API"
}

placeholder_image_ref() {
  printf '%s@sha256:<digest>\n' "$(image_repo)"
}

ssh_target() {
  printf '%s@%s\n' "$PRODUCTION_SSH_USER" "$PRODUCTION_SSH_HOST"
}

ssh_opts_words() {
  if [ -n "$SSH_OPTS" ]; then
    printf '%s ' $SSH_OPTS
  fi
}

push_image() {
  current_git_sha="$(git_sha)"
  current_short_sha="$(short_sha)"
  stamp="$(utc_stamp)"
  repo_ref="$(image_repo)"
  git_tag="$repo_ref:git-$current_git_sha"
  release_tag="$repo_ref:prod-$stamp-$current_short_sha"

  if [ "$dry_run" -eq 1 ]; then
    printf '[dry-run] aws ecr get-login-password --region %s | docker login --username AWS --password-stdin %s\n' "$AWS_REGION" "$ECR_REGISTRY"
    printf '[dry-run] cd %s && docker build -f Dockerfile.deploy -t %s -t %s .\n' "$SERVER_REPO_DIR" "$git_tag" "$release_tag"
    printf '[dry-run] docker push %s\n' "$git_tag"
    printf '[dry-run] docker push %s\n' "$release_tag"
    printf '[dry-run] Immutable image ref will look like %s\n' "$(placeholder_image_ref)"
    return 0
  fi

  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$ECR_REGISTRY"

  (
    cd "$SERVER_REPO_DIR"
    docker build -f Dockerfile.deploy -t "$git_tag" -t "$release_tag" .
  )

  docker push "$git_tag"
  docker push "$release_tag"

  immutable_ref="$(docker image inspect --format '{{index .RepoDigests 0}}' "$git_tag")"
  if [ -z "$immutable_ref" ]; then
    echo "Failed to resolve immutable image ref after push." >&2
    exit 1
  fi

  printf '%s\n' "$immutable_ref"
}

remote_deploy_script() {
  cat <<'EOF'
set -u

runtime_root="${RUNTIME_ROOT:?Missing RUNTIME_ROOT}"
deploy_env="$runtime_root/env/deploy.env"
log_file="$runtime_root/deploy-log.jsonl"

if [ ! -f "$deploy_env" ]; then
  echo "Missing $deploy_env" >&2
  exit 1
fi

previous_image_ref=""
if grep -q '^API_IMAGE=' "$deploy_env"; then
  previous_image_ref="$(sed -n 's/^API_IMAGE=//p' "$deploy_env" | tail -n 1)"
fi

tmp_deploy_env="$deploy_env.tmp.$$"
if grep -q '^API_IMAGE=' "$deploy_env"; then
  sed "s|^API_IMAGE=.*$|API_IMAGE=$IMAGE_REF|" "$deploy_env" >"$tmp_deploy_env"
else
  cat "$deploy_env" >"$tmp_deploy_env"
  printf '\nAPI_IMAGE=%s\n' "$IMAGE_REF" >>"$tmp_deploy_env"
fi
mv "$tmp_deploy_env" "$deploy_env"

deploy_result="success"
smoke_result="skipped"
status="success"

if ! RUNTIME_ROOT="$runtime_root" sh "$runtime_root/scripts/deploy.sh"; then
  deploy_result="failed"
  status="failed"
elif ! BASE_URL="$SMOKE_BASE_URL" sh "$runtime_root/scripts/smoke.sh"; then
  smoke_result="failed"
  status="failed"
else
  smoke_result="success"
fi

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
mkdir -p "$(dirname "$log_file")"
printf '{"timestamp":"%s","action":"%s","image_ref":"%s","previous_image_ref":"%s","deploy_result":"%s","smoke_result":"%s"}\n' \
  "$timestamp" \
  "$ACTION" \
  "$IMAGE_REF" \
  "$previous_image_ref" \
  "$deploy_result" \
  "$smoke_result" >>"$log_file"

if [ "$status" != "success" ]; then
  exit 1
fi
EOF
}

deploy_image() {
  action="$1"
  image_ref="$2"
  target="$(ssh_target)"
  ssh_opts_rendered="$(ssh_opts_words)"

  if [ "$dry_run" -eq 1 ]; then
    printf '[dry-run] update %s/env/deploy.env with API_IMAGE=%s\n' "$PRODUCTION_RUNTIME_ROOT" "$image_ref"
    printf '[dry-run] run %s/scripts/deploy.sh on %s\n' "$PRODUCTION_RUNTIME_ROOT" "$target"
    printf '[dry-run] run %s/scripts/smoke.sh on %s with BASE_URL=%s\n' "$PRODUCTION_RUNTIME_ROOT" "$target" "$SMOKE_BASE_URL"
    printf "[dry-run] ssh %s%s <<'EOF'\n" "$ssh_opts_rendered" "$target"
    printf 'export ACTION=%s\n' "$action"
    printf 'export IMAGE_REF=%s\n' "$image_ref"
    printf 'export RUNTIME_ROOT=%s\n' "$PRODUCTION_RUNTIME_ROOT"
    printf 'export SMOKE_BASE_URL=%s\n' "$SMOKE_BASE_URL"
    remote_deploy_script
    printf 'EOF\n'
    return 0
  fi

  ssh $SSH_OPTS "$target" \
    "ACTION='$action' IMAGE_REF='$image_ref' RUNTIME_ROOT='$PRODUCTION_RUNTIME_ROOT' SMOKE_BASE_URL='$SMOKE_BASE_URL' sh -s" <<EOF
$(remote_deploy_script)
EOF
}

load_env
validate_local_state

case "$command_name" in
  push)
    if [ "$#" -ne 0 ]; then
      usage >&2
      exit 1
    fi
    push_image
    ;;
  deploy)
    if [ "$#" -ne 1 ]; then
      usage >&2
      exit 1
    fi
    deploy_image "deploy" "$1"
    ;;
  ship)
    if [ "$#" -ne 0 ]; then
      usage >&2
      exit 1
    fi
    if [ "$dry_run" -eq 1 ]; then
      push_image
      deploy_image "deploy" "$(placeholder_image_ref)"
    else
      pushed_image_ref="$(push_image)"
      deploy_image "deploy" "$pushed_image_ref"
    fi
    ;;
  rollback)
    if [ "$#" -ne 1 ]; then
      usage >&2
      exit 1
    fi
    deploy_image "rollback" "$1"
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
