locals {

  env_prefix = {
    development = "dev."
    qa          = "qa."
    stage       = "stg."
    integration = "int."
    preprod     = "pre."
    production  = ""
  }

  env_certificate_bucket = "dw-${local.environment}-public-certificates"
  dks_endpoint           = data.terraform_remote_state.crypto.outputs.dks_endpoint[local.environment]

  dataworks_domain_name = "dataworks.dwp.gov.uk"
  lb_dns_name           = "bgdc-interface.${local.env_prefix[local.environment]}"
  full_lb_dns_name      = "${local.lb_dns_name}${local.dataworks_domain_name}"


  crypto_workspace = {
    management-dev = "management-dev"
    management     = "management"
  }

  management_workspace = {
    management-dev = "default"
    management     = "management"
  }

  management_account = {
    development = "management-dev"
    qa          = "management-dev"
    integration = "management-dev"
    preprod     = "management"
    production  = "management"
  }

  keep_cluster_alive = {
    development = true
    qa          = true
    integration = true
    preprod     = true
    production  = true
  }

  step_fail_action = {
    development = "CONTINUE"
    qa          = "TERMINATE_CLUSTER"
    integration = "TERMINATE_CLUSTER"
    preprod     = "TERMINATE_CLUSTER"
    production  = "TERMINATE_CLUSTER"
  }

  hbase_root_path          = format("s3://%s", data.terraform_remote_state.ingest.outputs.s3_buckets.hbase_rootdir)
  s3_log_prefix            = "emr/bgdc_interface"
  emrfs_metadata_tablename = "Analytical_Dataset_Generation_Metadata"
  data_pipeline_metadata   = data.terraform_remote_state.internal_compute.outputs.data_pipeline_metadata_dynamo.name

  ebs_emrfs_em = {
    EncryptionConfiguration = {
      EnableInTransitEncryption = false
      EnableAtRestEncryption    = true
      AtRestEncryptionConfiguration = {

        S3EncryptionConfiguration = {
          EncryptionMode             = "CSE-Custom"
          S3Object                   = "s3://${data.terraform_remote_state.management_mgmt.outputs.artefact_bucket.id}/emr-encryption-materials-provider/encryption-materials-provider-all.jar"
          EncryptionKeyProviderClass = "uk.gov.dwp.dataworks.dks.encryptionmaterialsprovider.DKSEncryptionMaterialsProvider"
        }
        LocalDiskEncryptionConfiguration = {
          EnableEbsEncryption       = true
          EncryptionKeyProviderType = "AwsKms"
          AwsKmsKey                 = aws_kms_key.bgdc_ebs_cmk.arn
        }
      }
    }
  }

  amazon_region_domain = "${data.aws_region.current.name}.amazonaws.com"
  endpoint_services    = ["dynamodb", "ec2", "ec2messages", "glue", "kms", "logs", "monitoring", ".s3", "s3", "secretsmanager", "ssm", "ssmmessages", "elasticloadbalancing"]
  no_proxy             = "169.254.169.254,${join(",", formatlist("%s.%s", local.endpoint_services, local.amazon_region_domain))}"

  hive_metastore_backend = {
    development = "aurora"
    qa          = "aurora"
    integration = "aurora"
    preprod     = "aurora"
    production  = "aurora"
  }

  component = "bgdc"

  bgdc_log_level = {
    development = "DEBUG"
    qa          = "DEBUG"
    integration = "DEBUG"
    preprod     = "INFO"
    production  = "INFO"
  }

  bgdc_version = {
    development = "0.0.1"
    qa          = "0.0.1"
    integration = "0.0.1"
    preprod     = "0.0.1"
    production  = "0.0.1"
  }

  cw_agent_namespace                   = "/app/bgdc"
  cw_agent_log_group_name              = "/app/bgdc"
  cw_agent_bootstrap_loggrp_name       = "/app/bgdc/bootstrap_actions"
  cw_agent_steps_loggrp_name           = "/app/bgdc/step_logs"
  cw_agent_yarnspark_loggrp_name       = "/app/bgdc/yarn-spark_logs"
  cw_agent_metrics_collection_interval = 60

  emr_config_s3_prefix = "emr/bgdc"

  ghostunnel_binary_name = "ghostunnel-v1.5.3-linux-amd64-with-pkcs11"
}
