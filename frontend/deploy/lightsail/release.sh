#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 || ! $1 =~ ^sha256:[a-f0-9]{64}$ ]]; then
  printf 'Usage: %s sha256:DIGEST\n' "$0" >&2
  exit 2
fi

registry=183603739306.dkr.ecr.ap-northeast-2.amazonaws.com
image="$registry/hodlit-prod-frontend@$1"
service=hodlit-prod-frontend
previous="$service-previous"
health_url=http://127.0.0.1:3000/
umask 077

exec 9>/run/lock/hodlit-frontend-deploy.lock
flock 9

if [[ $(docker inspect --format '{{.Config.Image}}' "$service" 2>/dev/null || true) == "$image" ]] &&
  curl --fail --silent --max-time 5 "$health_url" >/dev/null; then
  exit 0
fi

docker_config=$(mktemp -d)
trap 'if [[ -f $docker_config/config.json ]]; then unlink -- "$docker_config/config.json"; fi; rmdir -- "$docker_config"' EXIT
aws ecr get-login-password --region ap-northeast-2 |
  docker --config "$docker_config" login --username AWS --password-stdin "$registry" >/dev/null
docker --config "$docker_config" pull "$image"

if docker container inspect "$service" >/dev/null 2>&1; then
  if docker container inspect "$previous" >/dev/null 2>&1; then
    docker container rm "$previous" >/dev/null
  fi
  docker container rename "$service" "$previous"
  docker container stop --time 15 "$previous" >/dev/null
fi

if docker run -d --name "$service" --restart unless-stopped --memory 1300m \
  --log-opt max-size=10m --log-opt max-file=3 --publish 127.0.0.1:3000:3000 "$image"; then
  for attempt in {1..30}; do
    if curl --fail --silent --max-time 5 "$health_url" >/dev/null; then
      printf 'Deployed %s\n' "$image"
      exit 0
    fi
    sleep 2
  done
fi

if docker container inspect "$service" >/dev/null 2>&1; then
  docker logs --tail 20 "$service" >&2
  docker container stop --time 15 "$service" >/dev/null
  docker container rm "$service" >/dev/null
fi
if docker container inspect "$previous" >/dev/null 2>&1; then
  docker container rename "$previous" "$service"
  docker container start "$service" >/dev/null
fi
printf 'Frontend deployment failed for %s\n' "$image" >&2
exit 1
