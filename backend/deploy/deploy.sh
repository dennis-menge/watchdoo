#!/usr/bin/env bash
# Deploy Watchdoo Backend to Azure Container Apps
# Usage: ./deploy.sh
set -euo pipefail

# --- Configuration ---
RESOURCE_GROUP="watchdoo-rg"
LOCATION="westeurope"
CONTAINER_APP_ENV="watchdoo-env"
CONTAINER_APP_NAME="watchdoo-api"
IMAGE_NAME="watchdoo-backend"
ACR_NAME=""  # Leave empty to use local build + Azure managed registry

echo "=== Watchdoo – Azure Deployment ==="

# Check required env vars
for var in COOKIDOO_EMAIL COOKIDOO_PASSWORD API_KEY; do
    if [ -z "${!var:-}" ]; then
        echo "❌ Error: $var environment variable is not set"
        echo "   Export it before running: export $var=your-value"
        exit 1
    fi
done

COOKIDOO_COUNTRY="${COOKIDOO_COUNTRY:-de}"
COOKIDOO_LANGUAGE="${COOKIDOO_LANGUAGE:-de-DE}"

# 1. Create resource group
echo "📦 Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

# 2. Create Container Apps environment
echo "🌐 Creating Container Apps environment..."
az containerapp env create \
    --name "$CONTAINER_APP_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none 2>/dev/null || true

# 3. Build and deploy (using Azure managed build)
echo "🚀 Building and deploying container app..."
az containerapp up \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$CONTAINER_APP_ENV" \
    --source ../  \
    --ingress external \
    --target-port 8000 \
    --env-vars \
        "COOKIDOO_EMAIL=$COOKIDOO_EMAIL" \
        "COOKIDOO_PASSWORD=$COOKIDOO_PASSWORD" \
        "COOKIDOO_COUNTRY=$COOKIDOO_COUNTRY" \
        "COOKIDOO_LANGUAGE=$COOKIDOO_LANGUAGE" \
        "API_KEY=$API_KEY" \
    --output none

# 4. Configure scale-to-zero
echo "⚡ Configuring scale-to-zero..."
az containerapp update \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --min-replicas 0 \
    --max-replicas 1 \
    --output none

# 5. Get the URL
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
echo ""
echo "Enter these in your Watch app settings:"
echo "  Server URL: https://$FQDN"
echo "  API Key:    $API_KEY"
