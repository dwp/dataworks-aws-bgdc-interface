resource "aws_s3_bucket_object" "ghostunnel_service" {
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/${local.component}/ghostunnel_service"
  content    = file("${path.module}/steps/ghostunnel_service")
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn
}

resource "aws_s3_bucket_object" "ghostunnel-setup" {
  bucket = data.terraform_remote_state.common.outputs.config_bucket.id
  key    = "component/${local.component}/ghostunnel-setup.sh"
  content = templatefile("${path.module}/steps/ghostunnel-setup.tpl",
    {
      aws_default_region             = "eu-west-2"
      full_proxy                     = data.terraform_remote_state.internal_compute.outputs.internet_proxy.url
      full_no_proxy                  = local.no_proxy
      private_key_alias              = "private_key"
      artefact_bucket                = data.terraform_remote_state.management_mgmt.outputs.artefact_bucket.id
      ghostunnel_binary_name         = local.ghostunnel_binary_name
      ghostunnel_service_script_name = format("s3://%s/%s", data.terraform_remote_state.common.outputs.config_bucket.id, aws_s3_bucket_object.ghostunnel_service.key)
      target_group_arn               = aws_lb_target_group.bgdc_interface_hive.arn
  })
}
