#!/usr/bin/env bash
# Reserve the Azure resources: resource group, container registry, Container Apps environment.
# Safe to re-run: existing resources are reused. Saves names to .deploy.env for build_push.sh.
set -euo pipefail
 
STATE_FILE="$(dirname "$0")/.deploy.env"
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE"   # reuse names from a previous run
 
RG="${RG:-rg-shortener}"
LOC="${LOC:-northeurope}"
ENV_NAME="${ENV_NAME:-shortener-env}"
ACR="${ACR:-shortener${RANDOM}${RANDOM}}"        # globally unique, lowercase letters/digits only
 
az account show >/dev/null 2>&1 || { echo "Not logged in. Run: az login" >&2; exit 1; }
echo "Subscription: $(az account show --query name -o tsv)"
echo "Resource group: $RG | Location: $LOC | Registry: $ACR | Environment: $ENV_NAME"
 
echo "==> Installing/updating the containerapp CLI extension"
az extension add --name containerapp --upgrade --only-show-errors
 
echo "==> Registering resource providers (runs in the background)"
for ns in Microsoft.App Microsoft.OperationalInsights Microsoft.ContainerRegistry; do
  az provider register --namespace "$ns" --only-show-errors >/dev/null
done
 
echo "==> Resource group"
az group create -n "$RG" -l "$LOC" -o none
 
echo "==> Container registry (Basic SKU, admin user enabled)"
az acr create -n "$ACR" -g "$RG" --sku Basic --admin-enabled true -o none
 
echo "==> Container Apps environment (also creates a Log Analytics workspace)"
if az containerapp env show -n "$ENV_NAME" -g "$RG" >/dev/null 2>&1; then
  echo "    already exists, skipping"
else
  az containerapp env create -n "$ENV_NAME" -g "$RG" -l "$LOC" -o none
fi
 
cat > "$STATE_FILE" <<STATE
RG=$RG
LOC=$LOC
ENV_NAME=$ENV_NAME
ACR=$ACR
STATE
 
echo "Done. Settings saved to $STATE_FILE"
echo "Next: ./build_push.sh --deploy"