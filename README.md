# Azure Real-Time Fraud Detection System

Real-time fraud detection for financial transactions using Azure Event Hubs, Functions, and Cosmos DB with Terraform IaC.

## Architecture

- **Event Hubs**: Transaction stream ingestion
- **Azure Functions**: Real-time fraud detection logic
- **Cosmos DB**: Transaction storage and history
- **Key Vault**: Secure credential management
- **Managed Identity**: Zero-trust authentication
- **Application Insights**: Monitoring and alerting

## Features

✅ Real-time event processing (1000+ TPS)  
✅ Multi-factor fraud detection rules  
✅ Zero-trust security with Managed Identity  
✅ Infrastructure as Code with Terraform  
✅ PCI-DSS and SOC 2 compliance patterns  

## Quick Start

```bash
# Configure Azure CLI
az login

# Deploy infrastructure
./scripts/deploy.sh

# Test the system
./scripts/test-transaction.sh

# View logs
az functionapp log tail \
  -n $(terraform output -raw function_app_name) \
  -g $(terraform output -raw resource_group_name)
```

## Configuration

Edit `terraform.tfvars`:
- `alert_email`: Your email for fraud alerts
- `fraud_threshold`: Dollar amount trigger (default: $1000)
- `velocity_threshold`: Transaction count trigger (default: 5)

## Fraud Detection Rules

- High amount transactions (>$1000)
- International locations
- Round number amounts
- Late night activity (00:00-05:00)
- High velocity (>5 transactions)

## Cost Estimate

~$20-30/month for development usage

## Cleanup

```bash
terraform destroy
```

## Resume Talking Points

- Real-time fraud detection processing 1000+ TPS
- Zero-trust security with Azure Managed Identity
- Event-driven architecture for fintech compliance
- Infrastructure as Code with Terraform
