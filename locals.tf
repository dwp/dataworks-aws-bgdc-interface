locals {

  env_prefix = {
    development = "dev."
    qa          = "qa."
    stage       = "stg."
    integration = "int."
    preprod     = "pre."
    production  = ""
  }

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

  truststore_aliases = {
    development = "dataworks_root_ca,dataworks_mgt_root_ca"
    qa          = "dataworks_root_ca,dataworks_mgt_root_ca"
    integration = "dataworks_root_ca,dataworks_mgt_root_ca"
    preprod     = "dataworks_root_ca,dataworks_mgt_root_ca"
    production  = "dataworks_root_ca,dataworks_mgt_root_ca"
  }

  truststore_certs = {
    development = "s3://${data.terraform_remote_state.aws_certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
    qa          = "s3://${data.terraform_remote_state.aws_certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
    integration = "s3://${data.terraform_remote_state.aws_certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
    preprod     = "s3://${data.terraform_remote_state.aws_certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
    production  = "s3://${data.terraform_remote_state.aws_certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
  }

  env_certificate_bucket = "dw-${local.environment}-public-certificates"

  iam_role_max_session_timeout_seconds = 43200

  amazon_region_domain = "${data.aws_region.current.name}.amazonaws.com"
  endpoint_services    = ["dynamodb", "ec2", "ec2messages", "glue", "kms", "logs", "monitoring", ".s3", "s3", "secretsmanager", "ssm", "ssmmessages", "elasticloadbalancing"]
  no_proxy             = "169.254.169.254,${join(",", formatlist("%s.%s", local.endpoint_services, local.amazon_region_domain))}"

  dks_endpoint = data.terraform_remote_state.crypto.outputs.dks_endpoint[local.environment]

  emr_clusters = {
    bgdc_interface          = "bgdc-interface"
    bgdc_interface_metadata = "bgdc-interface-metadata"
  }

  dataworks_domain_name = "dataworks.dwp.gov.uk"

  emr_config_s3_prefix = {
    bgdc_interface          = "emr/bgdc-interface"
    bgdc_interface_metadata = "emr/bgdc-interface-metadata"
  }

  s3_log_prefix = {
    bgdc_interface          = "emr/bgdc-interface"
    bgdc_interface_metadata = "emr/bgdc-interface-metadata"
  }

  component = {
    bgdc_interface          = "bgdc-interface"
    bgdc_interface_metadata = "bgdc-interface-metadata"
  }

  ghostunnel_binary_name = "ghostunnel-v1.5.3-linux-amd64-with-pkcs11"

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

  hbase_root_path = format("s3://%s", data.terraform_remote_state.ingest.outputs.s3_buckets.hbase_rootdir)

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

  hive_metastore_backend = {
    development = "aurora"
    qa          = "aurora"
    integration = "aurora"
    preprod     = "aurora"
    production  = "aurora"
  }

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

  cw_agent_metrics_collection_interval = 60

  cw_agent_namespace = {
    bgdc_interface          = "/app/bgdc-interface"
    bgdc_interface_metadata = "/app/bgdc-interface-metadata"
  }
  cw_agent_log_group_name = {
    bgdc_interface          = "/app/bgdc-interface"
    bgdc_interface_metadata = "/app/bgdc-interface-metadata"
  }
  cw_agent_bootstrap_loggrp_name = {
    bgdc_interface          = "/app/bgdc-interface/bootstrap_actions"
    bgdc_interface_metadata = "/app/bgdc-interface-metadata/bootstrap_actions"
  }
  cw_agent_steps_loggrp_name = {
    bgdc_interface          = "/app/bgdc-interface/step_logs"
    bgdc_interface_metadata = "/app/bgdc-interface-metadata/step_logs"
  }
  cw_agent_yarnspark_loggrp_name = {
    bgdc_interface          = "/app/bgdc-interface/yarn-spark_logs"
    bgdc_interface_metadata = "/app/bgdc-interface-metadata/yarn-spark_logs"
  }

  parquet_permissions = {
    bgdc_interface          = "Allow"
    bgdc_interface_metadata = "Deny"
  }

  profiling_node_dns_name = "profiling-node.${local.env_prefix[local.environment]}${local.dataworks_domain_name}"

  profiling_node_ec2_size = {
    development = "t2.medium"
    qa          = "t2.medium"
    integration = "t2.medium"
    preprod     = "t2.medium"
    production  = "t2.medium"
  }

  asg_ssmenabled = {
    development = "True"
    qa          = "True"
    integration = "True"
    preprod     = "False" // OFF by IAM Policy
    production  = "False" // OFF by IAM Policy
  }

  cw_agent_profiling_node_log_group_name = "/app/profiling_node"

  peer_with_bgdc = {
    development = true
    qa          = false
    integration = false
    preprod     = false
    production  = false
  }

  peer_with_bgdc_vpc_id = {
    development = local.bgdc_vpc_peering.sandbox.vpc_id
    qa          = "undef"
    integration = "undef"
    preprod     = "undef"
    production  = "undef"
  }

  peer_with_bgdc_owner_id = {
    development = local.bgdc_vpc_peering.sandbox.owner
    qa          = "undef"
    integration = "undef"
    preprod     = "undef"
    production  = "undef"
  }

  peer_with_bgdc_source_cidrs = {
    development = local.bgdc_vpc_peering.sandbox.subnet_cidr_blocks
    qa          = ["127.0.0.1/32"] // Terraform won't accept "undef" as a CIDR value
    integration = ["127.0.0.1/32"] // Terraform won't accept "undef" as a CIDR value
    preprod     = ["127.0.0.1/32"] // Terraform won't accept "undef" as a CIDR value
    production  = ["127.0.0.1/32"] // Terraform won't accept "undef" as a CIDR value
  }
}
