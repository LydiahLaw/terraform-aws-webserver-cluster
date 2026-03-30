variable "cluster_name" {
  description = "The name to use for all cluster resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the cluster"
  type        = string
  default     = "t2.micro"
}

variable "min_size" {
  description = "Minimum number of EC2 instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of EC2 instances in the ASG"
  type        = number
  default     = 3
}

variable "server_port" {
  description = "Port the server uses for HTTP"
  type        = number
  default     = 8080
}

variable "custom_tag" {
  description = "A custom tag to apply to all resources in the cluster"
  type        = string
  default     = "terraform-module"
}
variable "enable_autoscaling" {
  description = "Whether to create an autoscaling policy for the cluster"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Deployment environment: dev, staging, or production"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "enable_detailed_monitoring" {
  description = "Enable CloudWatch detailed monitoring alarm (incurs additional cost)"
  type        = bool
  default     = false
}

variable "use_existing_vpc" {
  description = "Whether to use an existing VPC instead of the default one"
  type        = bool
  default     = false
}