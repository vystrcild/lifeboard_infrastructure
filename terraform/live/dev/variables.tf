variable "location" {
  type        = string
  description = "(Optional) Location of the resource group"
  default     = "westeurope"
}

variable "project_name" {
  type        = string
  description = "(Required) Project name"
}

variable "environment" {
  type        = string
  description = "(Required) Environment name (DEV, TEST, PROD)"

  validation {
    condition     = can(regex("dev|test|prod", var.environment))
    error_message = "Err: Valid options are 'dev', 'test' or 'prod'."
  }
}
