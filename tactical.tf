# This is a tactical solution to allow BGDC Sandbox - Dataworks development connectivity


resource "aws_vpc_endpoint_service" "bgdc_interface_hive_for_bgdc_sandbox" {
  count                      = local.environment == "development" ? 1 : 0
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.bgdc_interface_hive["bgdc_interface"].arn]
  allowed_principals = [
    "arn:aws:iam::${local.account[local.environment]}:root",
    "arn:aws:iam::${local.bgdc_account.test}:root",
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-interface-hive"
    },
  )
}
