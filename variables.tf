variable "assume_role" {
  type        = string
  default     = "ci"
  description = "IAM role assumed by Concourse when running Terraform"
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "emr_ami_id" {
  description = "AMI ID to use for the HBase EMR nodes"
}

variable "emr_release" {
  default = {
    development = "5.29.0"
    qa          = "5.29.0"
    integration = "5.29.0"
    preprod     = "5.29.0"
    production  = "5.29.0"
  }
}

variable "emr_instance_type" {
  default = {
    development = "m5.2xlarge"
    qa          = "m5.2xlarge"
    integration = "m5.2xlarge"
    preprod     = "m5.2xlarge"
    production  = "m5.2xlarge"
  }
}

variable "emr_core_instance_count" {
  default = {
    development = "2"
    qa          = "2"
    integration = "2"
    preprod     = "2"
    production  = "2"
  }
}

variable "emr_num_cores_per_core_instance" {
  default = {
    development = "8"
    qa          = "8"
    integration = "8"
    preprod     = "8"
    production  = "8"
  }
}

variable "spark_kyro_buffer" {
  default = {
    development = "128"
    qa          = "128"
    integration = "128"
    preprod     = "2047m"
    production  = "2047m"
  }
}

# Note this isn't the amount of RAM the instance has; it's the maximum amount
# that EMR automatically configures for YARN. See
# https://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-hadoop-task-config.html
# (search for yarn.nodemanager.resource.memory-mb)
variable "emr_yarn_memory_gb_per_core_instance" {
  default = {
    development = "24"
    qa          = "24"
    integration = "24"
    preprod     = "24"
    production  = "24"
  }
}

variable "metadata_store_bgdc_username" {
  description = "Username for metadata store reader BGDC user"
  default     = "bgdc"
}
