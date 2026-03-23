#!/bin/bash

echo "[oracle] Waiting for Docker daemon to be ready..."
for i in $(seq 1 15); do
  docker info > /dev/null 2>&1 && echo "[oracle] Docker is ready." && break \
    || { [ $i -lt 15 ] && sleep 3; }
done

echo "[oracle] Starting Oracle AI Database..."
docker compose -f .devcontainer/docker-compose.yml start oracle 2>/dev/null \
  || docker compose -f .devcontainer/docker-compose.yml up -d oracle

echo "[oracle] Oracle container started."
