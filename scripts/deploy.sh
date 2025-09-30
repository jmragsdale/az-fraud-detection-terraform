#!/bin/bash
set -e

echo "🚀 Deploying Azure Fraud Detection System..."

terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan

echo ""
echo "📊 Deployment Information:"
terraform output

echo ""
echo "📦 Packaging Function App..."
cd function-app
zip -r ../function-app.zip . -x "*.git*" "node_modules/*"
cd ..

FUNCTION_APP_NAME=$(terraform output -raw function_app_name)

echo "🚀 Deploying Function App code..."
az functionapp deployment source config-zip \
  -g $(terraform output -raw resource_group_name) \
  -n $FUNCTION_APP_NAME \
  --src function-app.zip

echo ""
echo "✅ Deployment complete!"
