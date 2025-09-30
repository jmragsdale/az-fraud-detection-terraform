variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-fraud-detection"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "fraud_threshold" {
  description = "Transaction amount threshold for fraud detection"
  type        = number
  default     = 1000
}

variable "velocity_threshold" {
  description = "Number of transactions in short time to trigger alert"
  type        = number
  default     = 5
}

variable "alert_email" {
  description = "Email address for fraud alerts"
  type        = string
  default     = "admin@example.com"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
