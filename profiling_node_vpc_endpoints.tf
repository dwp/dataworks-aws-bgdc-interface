resource "aws_vpc_endpoint_service" "bgdc_interface_vpce" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.bgdc_interface_emr["bgdc_interface"].arn]
  allowed_principals         = ["arn:aws:iam::${local.account[local.environment]}:root", ]

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-interface-vpce"
    },
  )
}

resource "aws_vpc_endpoint" "bgdc_interface_vpce" {
  vpc_id              = module.profiling_vpc.vpc.id
  service_name        = aws_vpc_endpoint_service.bgdc_interface_vpce.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.profiling.*.id
  private_dns_enabled = false

  security_group_ids = [
    aws_security_group.bgdc_interface_vpce.id,
  ]
}

resource "aws_security_group" "bgdc_interface_vpce" {
  name                   = "Hive Endpoint"
  description            = "Allows access to Hive VPC Endpoint Service for BGDC Interface"
  revoke_rules_on_delete = true
  vpc_id                 = module.profiling_vpc.vpc.id
}
