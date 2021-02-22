resource "aws_lb" "bgdc_interface_emr" {
  for_each                         = local.emr_clusters
  name                             = "${each.value}-hive"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids
  enable_cross_zone_load_balancing = true

  tags = merge(
    local.common_tags,
    {
      Name = "${each.value}-hive"
    },
  )
}

resource "aws_lb" "bgdc_interface_hive" {
  name                             = "bgdc-interface-hive"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids
  enable_cross_zone_load_balancing = true

  tags = merge(
  local.common_tags,
  {
    Name = "bgdc-interface-hive-old"
  },
  )
}

resource "aws_lb_listener" "bgdc_interface_hive" {
  for_each          = local.emr_clusters
  load_balancer_arn = aws_lb.bgdc_interface_emr[each.key].arn
  port              = "10443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bgdc_interface_hive[each.key].arn
  }
}

resource "aws_lb_target_group" "bgdc_interface_hive" {
  for_each             = local.emr_clusters
  name                 = "${each.value}-hive"
  port                 = 10443
  protocol             = "TCP"
  vpc_id               = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
  deregistration_delay = 10
  health_check {
    port     = 10443
    protocol = "TCP"
  }
}

# A workaround to allow traffic from NLB health check without allowing the whole VPC CIDR
data "aws_network_interface" "lb_eni_bgdc_interface" {
  count = "${length(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids)}"

  filter {
    name   = "description"
    values = ["ELB ${aws_lb.bgdc_interface_emr["bgdc_interface"].arn_suffix}"]
  }

  filter {
    name   = "subnet-id"
    values = ["${element(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids, count.index)}"]
  }
}

data "aws_network_interface" "lb_eni_bgdc_interface_metadata" {
  count = "${length(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids)}"

  filter {
    name   = "description"
    values = ["ELB ${aws_lb.bgdc_interface_emr["bgdc_interface_metadata"].arn_suffix}"]
  }

  filter {
    name   = "subnet-id"
    values = ["${element(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids, count.index)}"]
  }
}


resource "aws_security_group_rule" "lb_health_check_and_clients_bgdc_interface" {
  protocol          = "tcp"
  security_group_id = aws_security_group.bgdc_master.id
  from_port         = 10443
  to_port           = 10443
  cidr_blocks       = formatlist("%s/32", [for eni in data.aws_network_interface.lb_eni_bgdc_interface : eni.private_ip])
  type              = "ingress"
}

resource "aws_security_group_rule" "lb_health_check_and_clients_bgdc_interface_metadata" {
  protocol          = "tcp"
  security_group_id = aws_security_group.bgdc_master.id
  from_port         = 10443
  to_port           = 10443
  cidr_blocks       = formatlist("%s/32", [for eni in data.aws_network_interface.lb_eni_bgdc_interface_metadata : eni.private_ip])
  type              = "ingress"
}


resource "aws_route53_record" "bgdc_interface" {
  for_each = local.emr_clusters
  zone_id  = data.terraform_remote_state.management_mgmt.outputs.dataworks_zone.id
  name     = "${each.value}.${local.env_prefix[local.environment]}"
  type     = "A"

  alias {
    name                   = aws_lb.bgdc_interface_emr[each.key].dns_name
    zone_id                = aws_lb.bgdc_interface_emr[each.key].zone_id
    evaluate_target_health = false
  }

  provider = aws.management_mgmt
}
