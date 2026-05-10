#!/bin/sh

set -eu

runtime_root="${RUNTIME_ROOT:-/opt/hidden-adventures}"
postgres_env="$runtime_root/env/postgres.env"
deploy_env="$runtime_root/env/deploy.env"

if [ ! -f "$postgres_env" ]; then
  echo "Missing $postgres_env" >&2
  exit 1
fi

if [ ! -f "$deploy_env" ]; then
  echo "Missing $deploy_env" >&2
  exit 1
fi

. "$postgres_env"
. "$deploy_env"

: "${POSTGRES_USER:?Missing POSTGRES_USER in $postgres_env}"
: "${POSTGRES_DB:?Missing POSTGRES_DB in $postgres_env}"
: "${S3_BACKUP_BUCKET:?Missing S3_BACKUP_BUCKET in $deploy_env}"

timestamp="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
backup_dir="$runtime_root/backups"
backup_file="$backup_dir/db_$timestamp.dump"

mkdir -p "$backup_dir"

cd "$runtime_root"

docker compose exec -T postgres \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "$backup_file"

aws s3 cp "$backup_file" "s3://$S3_BACKUP_BUCKET/postgres/"

echo "Backup written to $backup_file and uploaded to s3://$S3_BACKUP_BUCKET/postgres/"
