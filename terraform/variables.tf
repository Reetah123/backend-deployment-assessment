variable "aws_region" {
  description = "AWS region for the assessment"
  type        = string
  default     = "eu-west-1"
}

variable "bastion_instance_type" {
  description = "Bastion EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "backend_instance_type" {
  description = "Backend EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "mongodb_instance_type" {
  description = "MongoDB EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "my_ip" {
  description = "My public IPv4 address"
  type        = list(string)
}

variable "key_name" {
  description = "My key pair"
  type        = string
}
