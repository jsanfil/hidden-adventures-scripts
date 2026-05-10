#!/bin/sh

set -eu

runtime_root="${RUNTIME_ROOT:-/opt/hidden-adventures}"
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
