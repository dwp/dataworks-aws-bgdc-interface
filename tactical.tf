# This is a tactical solution to allow BGDC Sandbox to Dataworks development connectivity

resource "aws_lb" "bgdc_tactical" {
  name                             = "bgdc-tactical"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids
  enable_cross_zone_load_balancing = true

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-tactical"
    },
  )
}

resource "aws_lb_listener" "bgdc_tactical" {
  load_balancer_arn = aws_lb.bgdc_tactical.arn
  port              = "10443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bgdc_tactical.arn
  }
}

resource "aws_lb_target_group" "bgdc_tactical" {
  name                 = "bgdc-tactical"
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
data "aws_network_interface" "lb_eni_bgdc_tactical" {
  count = length(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids)

  filter {
    name   = "description"
    values = ["ELB ${aws_lb.bgdc_tactical.arn_suffix}"]
  }

  filter {
    name   = "subnet-id"
    values = [element(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids, count.index)]
  }
}

resource "aws_security_group_rule" "lb_health_check_and_clients_bgdc_tactical" {
  protocol          = "tcp"
  security_group_id = aws_security_group.bgdc_master.id
  from_port         = 10443
  to_port           = 10443
  cidr_blocks       = formatlist("%s/32", [for eni in data.aws_network_interface.lb_eni_bgdc_tactical : eni.private_ip])
  type              = "ingress"
}

resource "aws_vpc_endpoint_service" "bgdc_tactical" {
  count                      = local.environment == "development" ? 1 : 0
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.bgdc_tactical.arn]
  allowed_principals = [
    "arn:aws:iam::${local.account[local.environment]}:root",
    "arn:aws:iam::${local.bgdc_account.development}:root",
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "bgdc-tactical"
    },
  )
}
