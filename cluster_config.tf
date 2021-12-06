resource "aws_emr_security_configuration" "ebs_emrfs_em" {
  name          = "bgdc_ebs_emrfs"
  configuration = jsonencode(local.ebs_emrfs_em)
}

resource "aws_s3_bucket_object" "cluster" {
  for_each = local.emr_clusters
  bucket   = data.terraform_remote_state.common.outputs.config_bucket.id
  key      = "${local.emr_config_s3_prefix[each.key]}/cluster.yaml"
  content = templatefile("${path.module}/cluster_config/cluster.yaml.tpl",
    {
      cluster_name           = each.value
      s3_log_bucket          = data.terraform_remote_state.security-tools.outputs.logstore_bucket.id
      s3_log_prefix          = local.s3_log_prefix[each.key]
      ami_id                 = var.emr_ami_id
      service_role           = aws_iam_role.bgdc_emr_service.arn
      instance_profile       = aws_iam_instance_profile.bgdc_interface[each.key].arn
      security_configuration = aws_emr_security_configuration.ebs_emrfs_em.id
      emr_release            = var.emr_release[local.environment]
    }
  )
}

resource "aws_s3_bucket_object" "instances" {
  for_each = local.emr_clusters

  bucket = data.terraform_remote_state.common.outputs.config_bucket.id
  key    = "${local.emr_config_s3_prefix[each.key]}/instances.yaml"
  content = templatefile("${path.module}/cluster_config/instances.yaml.tpl",
    {
      keep_cluster_alive  = local.keep_cluster_alive[local.environment]
      add_master_sg       = aws_security_group.bgdc_common.id
      add_slave_sg        = aws_security_group.bgdc_common.id
      subnet_ids          = join(",", data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids)
      master_sg           = aws_security_group.bgdc_master.id
      slave_sg            = aws_security_group.bgdc_slave.id
      service_access_sg   = aws_security_group.bgdc_emr_service.id
      instance_type       = var.emr_instance_type[local.environment]
      core_instance_count = var.emr_core_instance_count[local.environment]
    }
  )
}

resource "aws_s3_bucket_object" "steps" {
  bucket = data.terraform_remote_state.common.outputs.config_bucket.id
  key    = "${local.emr_config_s3_prefix[each.key]}/steps.yaml"
  content = templatefile("${path.module}/cluster_config/steps.yaml.tpl",
    {
      s3_config_bucket  = data.terraform_remote_state.common.outputs.config_bucket.id
      action_on_failure = local.step_fail_action[local.environment]
      component         = local.component[bgdc_interface_metadata]
    }
  )
}

# See https://aws.amazon.com/blogs/big-data/best-practices-for-successfully-managing-memory-for-apache-spark-applications-on-amazon-emr/
locals {
  spark_executor_cores                = 1
  spark_num_cores_per_core_instance   = var.emr_num_cores_per_core_instance[local.environment] - 1
  spark_num_executors_per_instance    = 5
  spark_executor_total_memory         = floor(var.emr_yarn_memory_gb_per_core_instance[local.environment] / local.spark_num_executors_per_instance)
  spark_executor_memory               = 20
  spark_yarn_executor_memory_overhead = 5
  spark_driver_memory                 = 10
  spark_driver_cores                  = 1
  spark_executor_instances            = 100
  spark_default_parallelism           = local.spark_executor_instances * local.spark_executor_cores * 2
  spark_kyro_buffer                   = var.spark_kyro_buffer[local.environment]
}

resource "aws_s3_bucket_object" "configurations" {
  for_each = local.emr_clusters

  bucket = data.terraform_remote_state.common.outputs.config_bucket.id
  key    = "${local.emr_config_s3_prefix[each.key]}/configurations.yaml"
  content = templatefile("${path.module}/cluster_config/configurations.yaml.tpl",
    {
      s3_log_bucket                = data.terraform_remote_state.security-tools.outputs.logstore_bucket.id
      s3_log_prefix                = local.s3_log_prefix[each.key]
      s3_published_bucket          = data.terraform_remote_state.common.outputs.published_bucket.id
      hive_metastore_username      = data.terraform_remote_state.internal_compute.outputs.metadata_store_users.bgdc.username
      hive_metastore_secret_name   = data.terraform_remote_state.internal_compute.outputs.metadata_store_users.bgdc.secret_name
      hive_metastore_endpoint      = data.terraform_remote_state.internal_compute.outputs.hive_metastore_v2.rds_cluster.endpoint
      hive_metastore_database_name = data.terraform_remote_state.internal_compute.outputs.hive_metastore_v2.rds_cluster.database_name
    }
  )
}
