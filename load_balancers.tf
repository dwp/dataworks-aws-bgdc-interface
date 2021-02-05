resource "aws_lb" "bgdc_interface_hive" {
  name               = "bgdc-interface-hive"
  internal           = true
  load_balancer_type = "network"
  subnets            = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids

  enable_deletion_protection = true

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-interface-hive"
    },
  )
}

resource "aws_lb_listener" "bgdc_interface_hive" {
  load_balancer_arn = aws_lb.bgdc_interface_hive.arn
  port              = "10443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bgdc_interface_hive.arn
  }
}

resource "aws_lb_target_group" "bgdc_interface_hive" {
  name                 = "bgdc-interface-hive"
  port                 = 10443
  protocol             = "TCP"
  vpc_id               = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
  deregistration_delay = 10
  health_check {
    port     = 10443
    protocol = "TCP"
  }
}

# A workaround to allow traffic from NLB health check and not allowing the whole VPC CIDR
data "aws_network_interface" "lb_eni" {
  count = "${length(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids)}"

  filter {
    name   = "description"
    values = ["ELB ${aws_lb.bgdc_interface_hive.arn_suffix}"]
  }

  filter {
    name   = "subnet-id"
    values = ["${element(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids, count.index)}"]
  }
}

resource "aws_security_group_rule" "lb_health_check" {
  protocol          = "tcp"
  security_group_id = aws_security_group.bgdc_master.id
  from_port         = 0
  to_port           = 65535
  cidr_blocks       = formatlist("%s/32", [for eni in data.aws_network_interface.lb_eni : eni.private_ip])
  type              = "ingress"
}

resource "aws_route53_record" "bgdc_interface" {
  zone_id = data.terraform_remote_state.management_mgmt.outputs.dataworks_zone.id
  name    = local.lb_dns_name
  type    = "A"

  alias {
    name                   = aws_lb.bgdc_interface_hive.dns_name
    zone_id                = aws_lb.bgdc_interface_hive.zone_id
    evaluate_target_health = false
  }

  provider = aws.management_mgmt
}
