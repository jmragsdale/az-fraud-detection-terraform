#!/bin/bash

RESOURCE_GROUP=$(terraform output -raw resource_group_name)
NAMESPACE=$(terraform output -raw eventhub_namespace)

echo "🧪 Testing Fraud Detection System"
echo ""

echo "1️⃣ Sending normal transaction..."
az eventhubs eventhub send \
  --name transactions \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --body "{
    \"transactionId\": \"TXN-$(date +%s)\",
    \"accountId\": \"ACC-12345\",
    \"amount\": 45.99,
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"merchantId\": \"MERCHANT-001\",
    \"location\": {\"country\": \"US\", \"city\": \"Atlanta\"}
  }"

echo "✅ Normal transaction sent"
sleep 2

echo ""
echo "2️⃣ Sending high-risk transaction..."
az eventhubs eventhub send \
  --name transactions \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --body "{
    \"transactionId\": \"TXN-$(date +%s)\",
    \"accountId\": \"ACC-12345\",
    \"amount\": 2500.00,
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"merchantId\": \"MERCHANT-999\",
    \"location\": {\"country\": \"RU\", \"city\": \"Moscow\"},
    \"transactionCount\": 8
  }"

echo "🚨 High-risk transaction sent"
