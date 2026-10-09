#!/usr/bin/env bash
# Build the Docker image locally, push it to your Azure Container Registry,
# and optionally create/update the container app.
# (Building locally avoids ACR Tasks, which some free subscriptions block.)
#
# Usage: ./build_push.sh [tag] [--deploy]
#   tag        image tag (default: timestamp, e.g. v20261009-142530)
#   --deploy   create the container app, or update it to the new image
set -euo pipefail
 
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="$SCRIPT_DIR/.deploy.env"
[[ -f "$STATE_FILE" ]] || { echo "Missing $STATE_FILE. Run ./provision.sh first." >&2; exit 1; }
source "$STATE_FILE"
 
APP_NAME="${APP_NAME:-shortener}"
IMAGE_NAME="${IMAGE_NAME:-shortener}"
TARGET_PORT="${TARGET_PORT:-8000}"
BUILD_CONTEXT="${BUILD_CONTEXT:-$SCRIPT_DIR/..}"   # folder containing the Dockerfile
 
TAG=""
DEPLOY=false
for arg in "$@"; do
  case "$arg" in
    --deploy) DEPLOY=true ;;
    *) TAG="$arg" ;;
  esac
done
TAG="${TAG:-v$(date +%Y%m%d-%H%M%S)}"
IMAGE="$ACR.azurecr.io/$IMAGE_NAME:$TAG"
 
az account show >/dev/null 2>&1 || { echo "Not logged in. Run: az login" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker isn't running." >&2; exit 1; }
 
echo "==> Logging in to registry $ACR"
az acr login -n "$ACR"
 
echo "==> Building $IMAGE"
docker build -t "$IMAGE" "$BUILD_CONTEXT"
 
echo "==> Pushing $IMAGE"
docker push "$IMAGE"
 
if [[ "$DEPLOY" == true ]]; then
  if az containerapp show -n "$APP_NAME" -g "$RG" >/dev/null 2>&1; then
    echo "==> Updating container app to $TAG"
    az containerapp update -n "$APP_NAME" -g "$RG" --image "$IMAGE" -o none
  else
    echo "==> Creating container app"
    ACR_USER="$(az acr credential show -n "$ACR" --query username -o tsv)"
    ACR_PASS="$(az acr credential show -n "$ACR" --query 'passwords[0].value' -o tsv)"
    az containerapp create -n "$APP_NAME" -g "$RG" --environment "$ENV_NAME" \
      --image "$IMAGE" \
      --registry-server "$ACR.azurecr.io" \
      --registry-username "$ACR_USER" --registry-password "$ACR_PASS" \
      --ingress external --target-port "$TARGET_PORT" -o none
  fi
  FQDN="$(az containerapp show -n "$APP_NAME" -g "$RG" --query properties.configuration.ingress.fqdn -o tsv)"
  echo "Deployed: https://$FQDN/health"
else
  echo "Pushed $IMAGE (re-run with --deploy to create/update the app)"
fi