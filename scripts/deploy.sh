#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <image-name> <image-tag>" >&2
  exit 2
fi

image_name="$1"
image_tag="$2"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
host_port="${HOST_PORT:-18080}"

if [[ ! "$image_tag" =~ ^[0-9a-f]{40}$ ]]; then
  echo "image tag must be a full 40-character Git commit SHA" >&2
  exit 2
fi

cd "$root_dir"

IMAGE_NAME="$image_name" IMAGE_TAG="$image_tag" docker compose pull app
IMAGE_NAME="$image_name" IMAGE_TAG="$image_tag" \
  docker compose up -d --no-build app

for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${host_port}/health" | grep -qx ok; then
    break
  fi
  sleep 1
done

curl -fsS "http://127.0.0.1:${host_port}/health" | grep -qx ok
curl -fsS "http://127.0.0.1:${host_port}/" | grep -Fq "$image_tag"

echo "Deployed ${image_name}:${image_tag}"
