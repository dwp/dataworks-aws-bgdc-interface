module "edc_vpc" {
  source         = "dwp/vpc/aws"
  version        = "3.0.9"
  vpc_name       = "edc"
  region         = var.region
  vpc_cidr_block = local.cidr_block[local.environment].bgdc-edc-vpc
  gateway_vpce_route_table_ids = [
  ]
  interface_vpce_source_security_group_ids = [
  ]
  interface_vpce_subnet_ids = aws_subnet.vpc_endpoints.*.id
  common_tags               = local.common_tags

  aws_vpce_services = [
    "ssm",
    "ssmmessages",
    "ec2",
    "ec2messages",
    "s3",
    "logs",
    "monitoring",
    "kms",
    "autoscaling",
    "secretsmanager",
    "elasticloadbalancing",
  ]
}

resource "aws_subnet" "vpc_endpoints" {
  count             = length(data.aws_availability_zones.available.names)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.edc_vpc.vpc.id

  cidr_block = cidrsubnet(
    module.edc_vpc.vpc.cidr_block,
    3,
    count.index,
  )

  tags = merge(
    local.common_tags,
    {
      "Name" = "vpc-endpoints"
    },
  )
}

resource "aws_security_group" "internet_proxy_endpoint" {
  name        = "proxy_vpc_endpoint"
  description = "Control access to the Internet Proxy VPC Endpoint"
  vpc_id      = module.edc_vpc.vpc.id
  tags        = local.common_tags
}

resource "aws_vpc_endpoint" "internet_proxy" {
  vpc_id              = module.edc_vpc.vpc.id
  service_name        = data.terraform_remote_state.internet_egress.outputs.internet_proxy_service.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.internet_proxy_endpoint.id]
  subnet_ids          = aws_subnet.vpc_endpoints.*.id
  private_dns_enabled = false
}


resource "aws_subnet" "edc" {
  count             = length(data.aws_availability_zones.available.names)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.edc_vpc.vpc.id

  cidr_block = cidrsubnet(
    module.edc_vpc.vpc.cidr_block,
    3,
    count.index + length(aws_subnet.vpc_endpoints),
  )

  tags = merge(
    local.common_tags,
    {
      "Name" = "edc"
    },
  )
}

resource "aws_route_table" "edc" {
  vpc_id = module.edc_vpc.vpc.id
  tags   = local.common_tags
}

resource "aws_route_table_association" "edc" {
  count          = length(aws_subnet.edc)
  subnet_id      = element(aws_subnet.edc.*.id, count.index)
  route_table_id = aws_route_table.edc.id
}
