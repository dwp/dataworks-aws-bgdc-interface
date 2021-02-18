resource "aws_s3_bucket_object" "metadata_script" {
  for_each   = local.emr_clusters
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/${local.component[each.key]}/metadata.sh"
  content    = file("${path.module}/bootstrap_actions/metadata.sh")
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn
}

resource "aws_s3_bucket_object" "emr_setup_sh" {
  for_each = local.emr_clusters
  bucket   = data.terraform_remote_state.common.outputs.config_bucket.id
  key      = "component/${local.component[each.key]}/emr-setup.sh"
  content = templatefile("${path.module}/bootstrap_actions/emr-setup.sh",
    {
      VERSION                         = local.bgdc_version[local.environment]
      BGDC_LOG_LEVEL                  = local.bgdc_log_level[local.environment]
      ENVIRONMENT_NAME                = local.environment
      S3_COMMON_LOGGING_SHELL         = format("s3://%s/%s", data.terraform_remote_state.common.outputs.config_bucket.id, data.terraform_remote_state.common.outputs.application_logging_common_file.s3_id)
      S3_LOGGING_SHELL                = format("s3://%s/%s", data.terraform_remote_state.common.outputs.config_bucket.id, aws_s3_bucket_object.logging_script[each.key].key)
      aws_default_region              = "eu-west-2"
      full_proxy                      = data.terraform_remote_state.internal_compute.outputs.internet_proxy.url
      full_no_proxy                   = local.no_proxy
      acm_cert_arn                    = aws_acm_certificate.bgdc_interface[each.key].arn
      private_key_alias               = "private_key"
      truststore_aliases              = join(",", var.truststore_aliases)
      truststore_certs                = "s3://${local.env_certificate_bucket}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
      dks_endpoint                    = data.terraform_remote_state.crypto.outputs.dks_endpoint[local.environment]
      cwa_metrics_collection_interval = local.cw_agent_metrics_collection_interval
      cwa_namespace                   = local.cw_agent_namespace[each.key]
      cwa_log_group_name              = aws_cloudwatch_log_group.bgdc_emr[each.key].name
      S3_CLOUDWATCH_SHELL             = format("s3://%s/%s", data.terraform_remote_state.common.outputs.config_bucket.id, aws_s3_bucket_object.cloudwatch_sh[each.key].key)
      cwa_bootstrap_loggrp_name       = aws_cloudwatch_log_group.bgdc_emr_cw_bootstrap_loggroup[each.key].name
      cwa_steps_loggrp_name           = aws_cloudwatch_log_group.bgdc_emr_cw_steps_loggroup[each.key].name
      cwa_yarnspark_loggrp_name       = aws_cloudwatch_log_group.bgdc_emr_cw_yarnspark_loggroup[each.key].name
  })
}

resource "aws_s3_bucket_object" "ssm_script" {
  for_each = local.emr_clusters
  bucket   = data.terraform_remote_state.common.outputs.config_bucket.id
  key      = "component/${local.component[each.key]}/start_ssm.sh"
  content  = file("${path.module}/bootstrap_actions/start_ssm.sh")
}

resource "aws_s3_bucket_object" "installer_sh" {
  for_each = local.emr_clusters
  bucket   = data.terraform_remote_state.common.outputs.config_bucket.id
  key      = "component/${local.component[each.key]}/installer.sh"
  content = templatefile("${path.module}/bootstrap_actions/installer.sh",
    {
      full_proxy    = data.terraform_remote_state.internal_compute.outputs.internet_proxy.url
      full_no_proxy = local.no_proxy
    }
  )
}

resource "aws_s3_bucket_object" "logging_script" {
  for_each = local.emr_clusters
  bucket   = data.terraform_remote_state.common.outputs.config_bucket.id
  key      = "component/${local.component[each.key]}/logging.sh"
  content  = file("${path.module}/bootstrap_actions/logging.sh")
}

resource "aws_s3_bucket_object" "cloudwatch_sh" {
  for_each = local.emr_clusters
  bucket   = data.terraform_remote_state.common.outputs.config_bucket.id
  key      = "component/${local.component[each.key]}/cloudwatch.sh"
  content = templatefile("${path.module}/bootstrap_actions/cloudwatch.sh",
    {
      emr_release = var.emr_release[local.environment]
    }
  )
}

resource "aws_cloudwatch_log_group" "bgdc_emr" {
  for_each          = local.emr_clusters
  name              = local.cw_agent_log_group_name[each.key]
  retention_in_days = 180
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "bgdc_emr_cw_bootstrap_loggroup" {
  for_each          = local.emr_clusters
  name              = local.cw_agent_bootstrap_loggrp_name[each.key]
  retention_in_days = 180
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "bgdc_emr_cw_steps_loggroup" {
  for_each          = local.emr_clusters
  name              = local.cw_agent_steps_loggrp_name[each.key]
  retention_in_days = 180
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "bgdc_emr_cw_yarnspark_loggroup" {
  for_each          = local.emr_clusters
  name              = local.cw_agent_yarnspark_loggrp_name[each.key]
  retention_in_days = 180
  tags              = local.common_tags
}


# Deprecated log groups
resource "aws_cloudwatch_log_group" "bgdc" {
  name              = "/app/bgdc"
  retention_in_days = 180
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "bgdc_cw_bootstrap_loggroup" {
  name              = "/app/bgdc/bootstrap_actions"
  retention_in_days = 180
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "bgdc_cw_steps_loggroup" {
  name              = "/app/bgdc/step_logs"
  retention_in_days = 180
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "bgdc_cw_yarnspark_loggroup" {
  name              = "/app/bgdc/yarn-spark_logs"
  retention_in_days = 180
  tags              = local.common_tags
}
