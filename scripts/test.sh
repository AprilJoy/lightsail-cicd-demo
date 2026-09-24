#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="lightsail-cicd-demo:test"
container="lightsail-cicd-demo-test-$$"
version="test-commit-123"

cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker build --build-arg VERSION="$version" -t "$image" "$root_dir"
docker run -d --name "$container" -p 127.0.0.1::8080 "$image" >/dev/null

host_port="$(docker port "$container" 8080/tcp | awk -F: 'NR == 1 {print $NF}')"
base_url="http://127.0.0.1:$host_port"

for _ in $(seq 1 30); do
  if curl -fsS "$base_url/health" >/dev/null; then
    break
  fi
  sleep 1
done

health="$(curl -fsS "$base_url/health")"
home="$(curl -fsS "$base_url/")"

[[ "$health" == "ok" ]]
grep -Fq "CI/CD Demo" <<<"$home"
grep -Fq "$version" <<<"$home"

echo "Demo HTTP checks passed at $base_url"
