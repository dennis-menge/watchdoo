#!/usr/bin/env bash
# Deploy Watchdoo backend to Azure Container Apps.
#
# Idempotent: re-running re-uses existing resources where possible and
# otherwise updates them in place.
#
# Required env vars: COOKIDOO_EMAIL, COOKIDOO_PASSWORD, API_KEY
# Optional env vars: COOKIDOO_COUNTRY (default "de"),
#                    COOKIDOO_LANGUAGE (default "de-DE"),
#                    LOCATION (default "germanywestcentral"),
#                    RESOURCE_GROUP (default "watchdoo-rg"),
#                    SUBSCRIPTION (Azure subscription ID or name; optional)

set -euo pipefail

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-watchdoo-rg}"
LOCATION="${LOCATION:-germanywestcentral}"
LOG_WORKSPACE="watchdoo-logs"
CONTAINER_APP_ENV="watchdoo-env"
CONTAINER_APP_NAME="watchdoo-api"
IMAGE_NAME="watchdoo-backend"

echo "=== Watchdoo – Azure Deployment ==="

# --- Sanity checks ---
if ! command -v az >/dev/null 2>&1; then
    echo "❌ Azure CLI ('az') is not installed. See: https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

for var in COOKIDOO_EMAIL COOKIDOO_PASSWORD API_KEY; do
    if [ -z "${!var:-}" ]; then
        echo "❌ Error: $var is not set."
        echo "   Tip: source backend/.env first, e.g.  set -a && source backend/.env && set +a"
        exit 1
    fi
done

COOKIDOO_COUNTRY="${COOKIDOO_COUNTRY:-de}"
COOKIDOO_LANGUAGE="${COOKIDOO_LANGUAGE:-de-DE}"

if [ -n "${SUBSCRIPTION:-}" ]; then
    az account set --subscription "$SUBSCRIPTION"
fi

if ! az account show >/dev/null 2>&1; then
    echo "❌ Not logged in. Run 'az login' first."
    exit 1
fi

# Resolve the directory containing the Dockerfile (parent of this script).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONTEXT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ ! -f "$BUILD_CONTEXT/Dockerfile" ]; then
    echo "❌ No Dockerfile found at $BUILD_CONTEXT/Dockerfile"
    exit 1
fi

# --- 1. Register required providers (no-op if already registered) ---
echo "📋 Ensuring required resource providers are registered…"
for ns in Microsoft.App Microsoft.OperationalInsights Microsoft.ContainerRegistry; do
    state=$(az provider show --namespace "$ns" --query registrationState -o tsv 2>/dev/null || echo "NotRegistered")
    if [ "$state" != "Registered" ]; then
        echo "   - registering $ns…"
        az provider register --namespace "$ns" --wait --output none
    fi
done

# --- 2. Resource group ---
echo "📦 Resource group: $RESOURCE_GROUP ($LOCATION)"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

# --- 3. Log Analytics workspace (deterministic name → no orphans on re-run) ---
echo "📊 Log Analytics workspace: $LOG_WORKSPACE"
LOG_WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$LOG_WORKSPACE" \
    --query customerId -o tsv 2>/dev/null || echo "")
if [ -z "$LOG_WORKSPACE_ID" ]; then
    az monitor log-analytics workspace create \
        --resource-group "$RESOURCE_GROUP" \
        --workspace-name "$LOG_WORKSPACE" \
        --location "$LOCATION" \
        --output none
    LOG_WORKSPACE_ID=$(az monitor log-analytics workspace show \
        --resource-group "$RESOURCE_GROUP" \
        --workspace-name "$LOG_WORKSPACE" \
        --query customerId -o tsv)
fi
LOG_WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$LOG_WORKSPACE" \
    --query primarySharedKey -o tsv)

# --- 4. Container Apps environment ---
echo "🌐 Container Apps environment: $CONTAINER_APP_ENV"
if ! az containerapp env show -n "$CONTAINER_APP_ENV" -g "$RESOURCE_GROUP" >/dev/null 2>&1; then
    az containerapp env create \
        --name "$CONTAINER_APP_ENV" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --logs-workspace-id "$LOG_WORKSPACE_ID" \
        --logs-workspace-key "$LOG_WORKSPACE_KEY" \
        --output none
fi

# --- 5. Azure Container Registry (deterministic name per resource group) ---
# ACR names must be globally unique, alphanumeric, 5–50 chars.
RG_HASH=$(printf '%s' "$RESOURCE_GROUP" | shasum | cut -c1-8)
ACR_NAME="watchdooacr${RG_HASH}"
echo "🐳 Container Registry: $ACR_NAME"
if ! az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" >/dev/null 2>&1; then
    az acr create \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --sku Basic \
        --admin-enabled true \
        --location "$LOCATION" \
        --output none
fi
ACR_SERVER=$(az acr show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query loginServer -o tsv)
ACR_PASSWORD=$(az acr credential show -n "$ACR_NAME" -g "$RESOURCE_GROUP" --query "passwords[0].value" -o tsv)

# --- 6. Build image (server-side; no local Docker required) ---
echo "🛠  Building image $IMAGE_NAME:latest from $BUILD_CONTEXT (server-side)…"
az acr build \
    --registry "$ACR_NAME" \
    --image "$IMAGE_NAME:latest" \
    --file "$BUILD_CONTEXT/Dockerfile" \
    "$BUILD_CONTEXT" \
    --output none

IMAGE_REF="$ACR_SERVER/$IMAGE_NAME:latest"

# --- 7. Container app: create or update ---
COMMON_ENV_VARS=(
    "COOKIDOO_EMAIL=$COOKIDOO_EMAIL"
    "COOKIDOO_PASSWORD=secretref:cookidoo-password"
    "COOKIDOO_COUNTRY=$COOKIDOO_COUNTRY"
    "COOKIDOO_LANGUAGE=$COOKIDOO_LANGUAGE"
    "API_KEY=secretref:api-key"
)
SECRETS=(
    "cookidoo-password=$COOKIDOO_PASSWORD"
    "api-key=$API_KEY"
)

if az containerapp show -n "$CONTAINER_APP_NAME" -g "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "🚀 Updating existing container app: $CONTAINER_APP_NAME"
    az containerapp registry set \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$ACR_SERVER" \
        --username "$ACR_NAME" \
        --password "$ACR_PASSWORD" \
        --output none
    az containerapp secret set \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --secrets "${SECRETS[@]}" \
        --output none
    az containerapp update \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --image "$IMAGE_REF" \
        --set-env-vars "${COMMON_ENV_VARS[@]}" \
        --min-replicas 0 \
        --max-replicas 1 \
        --output none
else
    echo "🚀 Creating container app: $CONTAINER_APP_NAME"
    az containerapp create \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --environment "$CONTAINER_APP_ENV" \
        --image "$IMAGE_REF" \
        --target-port 8000 \
        --ingress external \
        --min-replicas 0 \
        --max-replicas 1 \
        --registry-server "$ACR_SERVER" \
        --registry-username "$ACR_NAME" \
        --registry-password "$ACR_PASSWORD" \
        --secrets "${SECRETS[@]}" \
        --env-vars "${COMMON_ENV_VARS[@]}" \
        --output none
fi

FQDN=$(az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.configuration.ingress.fqdn" \
    --output tsv)

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🔗 Backend URL: https://$FQDN"
echo "🔑 API Key:     $API_KEY"
echo ""
echo "Test it:"
echo "  curl https://$FQDN/api/v1/health"
echo "  curl -H \"X-API-Key: \$API_KEY\" https://$FQDN/api/v1/shopping-list"
echo ""
echo "Stream logs:"
echo "  az containerapp logs tail -n $CONTAINER_APP_NAME -g $RESOURCE_GROUP --follow"
echo ""
echo "Enter these on your iPhone in the Watchdoo companion app (then tap 'Send to Watch'):"
echo "  Server URL: https://$FQDN"
echo "  API Key:    $API_KEY"
