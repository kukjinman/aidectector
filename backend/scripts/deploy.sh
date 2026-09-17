#!/usr/bin/env bash
# Builds the backend Docker image locally and ships it to the AWS server
# over SSH — no Docker registry (Docker Hub / ECR) needed.
#
# Fill in the four variables below for your server, then run:
#   ./scripts/deploy.sh
#
# Re-run it any time backend/src changes to redeploy the latest code.

set -euo pipefail

# --- fill these in for your server ---------------------------------------
SSH_HOST="your-server-ip-or-domain"
SSH_USER="ubuntu"                 # or "ec2-user" for Amazon Linux
SSH_KEY="$HOME/.ssh/your-key.pem"
# Most EC2 instance types are x86_64; use "linux/arm64" for Graviton (e.g. t4g/c7g).
PLATFORM="linux/amd64"
# ---------------------------------------------------------------------------

IMAGE_NAME="aidetector-backend"
IMAGE_TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
TAR_PATH="/tmp/${IMAGE_NAME}.tar.gz"

echo "==> Building ${IMAGE_NAME}:${IMAGE_TAG} for ${PLATFORM}"
docker buildx build --platform "$PLATFORM" -t "${IMAGE_NAME}:${IMAGE_TAG}" --load "$BACKEND_DIR"

echo "==> Saving image to ${TAR_PATH}"
docker save "${IMAGE_NAME}:${IMAGE_TAG}" | gzip > "$TAR_PATH"

echo "==> Copying image and compose file to ${SSH_HOST}"
ssh -i "$SSH_KEY" "${SSH_USER}@${SSH_HOST}" "mkdir -p ~/aidetector-backend"
scp -i "$SSH_KEY" "$TAR_PATH" "${SSH_USER}@${SSH_HOST}:~/aidetector-backend/${IMAGE_NAME}.tar.gz"
scp -i "$SSH_KEY" "$BACKEND_DIR/docker-compose.yml" "${SSH_USER}@${SSH_HOST}:~/aidetector-backend/docker-compose.yml"

echo "==> Loading image and (re)starting the container on the server"
# NOTE: the server needs its own ~/aidetector-backend/.env (see .env.example) —
# this script never copies it, so a real API key is never sent over the deploy path.
ssh -i "$SSH_KEY" "${SSH_USER}@${SSH_HOST}" bash -s <<'REMOTE'
set -euo pipefail
cd ~/aidetector-backend
docker load < aidetector-backend.tar.gz
docker compose up -d
docker image prune -f
REMOTE

rm -f "$TAR_PATH"
echo "==> Done. Check with: ssh -i $SSH_KEY ${SSH_USER}@${SSH_HOST} 'docker compose -f ~/aidetector-backend/docker-compose.yml logs -f'"
