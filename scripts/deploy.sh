#!/bin/sh

set -eu

runtime_root="${RUNTIME_ROOT:-/opt/hidden-adventures}"
deploy_env="$runtime_root/env/deploy.env"
api_env="$runtime_root/env/api.env"
postgres_env="$runtime_root/env/postgres.env"

if [ ! -f "$deploy_env" ]; then
  echo "Missing $deploy_env" >&2
  exit 1
fi

if [ ! -f "$api_env" ]; then
  echo "Missing $api_env" >&2
  exit 1
fi

if [ ! -f "$postgres_env" ]; then
  echo "Missing $postgres_env" >&2
  exit 1
fi

. "$deploy_env"

: "${AWS_REGION:?Missing AWS_REGION in $deploy_env}"
: "${ECR_REGISTRY:?Missing ECR_REGISTRY in $deploy_env}"
: "${API_IMAGE:?Missing API_IMAGE in $deploy_env}"

cd "$runtime_root"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker compose --env-file "$deploy_env" pull api
docker compose --env-file "$deploy_env" up -d postgres
docker run --rm \
  --env-file "$api_env" \
  --env-file "$postgres_env" \
  "$API_IMAGE" \
  npm run db:migrate:dist
docker compose --env-file "$deploy_env" up -d api
docker compose --env-file "$deploy_env" ps
