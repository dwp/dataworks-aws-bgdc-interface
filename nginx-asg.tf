data "aws_ami" "bgdc_nginx_latest" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bgdc-nginx-main-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [local.bgdc_account.development]
}

resource "aws_launch_configuration" "nginx_conf" {
  name_prefix     = "dwx-bgdc-nginx-"
  image_id        = data.aws_ami.bgdc_nginx_latest.id
  instance_type   = "t2.medium"
  security_groups = [data.terraform_remote_state.internal_compute.outputs.vpce_security_groups.nginx_asg_bgdc_dwx.id]
  iam_instance_profile = aws_iam_instance_profile.dwx_bgdc_nginx_instance_profile.arn
 
  
  user_data = templatefile("bootstrapBgdcDwxNginx.template", { BgdcDwxListener = local.bgdc_dwx_listener[local.environment], BgdcDwxNginxDns = aws_lb.dwx_bdgc_nginx_emr_nlb.dns_name, BgdcDwxNginxPort = local.bgdc_dwx_nginx_target[local.environment] })

  root_block_device {
    volume_type           = "gp3"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nginx_asg" {
  name                      = "dwx-bgdc-nginx"
  max_size                  = 2
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  launch_configuration      = aws_launch_configuration.nginx_conf.name
  vpc_zone_identifier       = local.bgdc_private_subnets
  target_group_arns         = [aws_lb_target_group.dwx_bdgc_nginx_nlb_tg.arn]

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "dwx-bgdc-nginx-instances"
    propagate_at_launch = true
  }
}

resource "aws_lb" "dwx_bdgc_nginx_nlb" {
  name               = "dwx-bgdc-nginx-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = local.bgdc_private_subnets

  enable_deletion_protection = true

  enable_cross_zone_load_balancing = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Environment = local.environment
  }
}

resource "aws_lb_target_group" "dwx_bdgc_nginx_nlb_tg" {
  name     = "dwx-bgdc-nginx-nlb-tg"
  port     = local.bgdc_dwx_listener[local.environment]
  protocol = "TCP"
  target_type = "instance"
  vpc_id   = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id

  health_check {
    port = 80
    protocol          = "TCP"
    healthy_threshold = 3
    unhealthy_threshold = 3
    interval = 30
  }
}

resource "aws_lb_listener" "dwx_bdgc_nginx_nlb_listener" {
  load_balancer_arn = aws_lb.dwx_bdgc_nginx_nlb.arn
  port              = local.bgdc_dwx_listener[local.environment]
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.dwx_bdgc_nginx_nlb_tg.arn
    type             = "forward"
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_nginx_nlb" {
  autoscaling_group_name = aws_autoscaling_group.nginx_asg.id
  alb_target_group_arn   = aws_lb_target_group.dwx_bdgc_nginx_nlb_tg.id
}

resource "aws_lb" "dwx_bdgc_nginx_emr_nlb" {
  name               = "dwx-bgdc-nginx-emr-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids

  enable_deletion_protection = true

  enable_cross_zone_load_balancing = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Environment = local.environment
  }
}

resource "aws_lb_target_group" "dwx_bdgc_nginx_emr_nlb_tg" {
  name     = "dwx-bgdc-nginx-emr-nlb-tg"
  port     = local.bgdc_dwx_nginx_target[local.environment]
  protocol = "TCP"
  target_type = "instance"
  vpc_id   = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
}

resource "aws_lb_listener" "dwx_bdgc_nginx_emr_nlb_listener" {
  load_balancer_arn = aws_lb.dwx_bdgc_nginx_emr_nlb.arn
  port              = local.bgdc_dwx_nginx_target[local.environment]
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.dwx_bdgc_nginx_emr_nlb_tg.arn
    type             = "forward"
  }
}

resource "aws_vpc_endpoint_service" "bgdc_dwx_end_point_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.dwx_bdgc_nginx_nlb.arn]
  allowed_principals         = ["arn:aws:iam::${local.bgdc_account[local.environment]}:root"]
  
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "bgdc-dwx-endpoint-svc"
  }
}

resource "aws_security_group_rule" "allow_http_from_target_group_vpce" {
  description              = "HTTP from target group"
  from_port                = 80
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.internal_compute.outputs.vpce_security_groups.nginx_asg_bgdc_dwx.id
  to_port                  = 80
  type                     = "ingress"
  cidr_blocks              = formatlist("%s/32", [for eni in data.aws_network_interface.dwx_bdgc_nlb_ni : eni.private_ip])                             
}

resource "aws_security_group_rule" "allow_bgdc_from_target_group_vpce" {
  description              = "Allow bgdc port from target group"
  to_port                  = local.bgdc_dwx_listener[local.environment]
  from_port                = local.bgdc_dwx_listener[local.environment]
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.internal_compute.outputs.vpce_security_groups.nginx_asg_bgdc_dwx.id
  type                     = "ingress"
  cidr_blocks              = formatlist("%s/32", [for eni in data.aws_network_interface.dwx_bdgc_nlb_ni : eni.private_ip])                             
}

data "aws_network_interface" "dwx_bdgc_nlb_ni" {
  for_each = toset(local.bgdc_private_subnets)

  filter {
    name   = "description"
    values = ["ELB ${aws_lb.dwx_bdgc_nginx_nlb.arn_suffix}"]
  }

  filter {
    name   = "subnet-id"
    values = [each.value]
  }
}

resource "aws_security_group_rule" "allow_nginx_egress_emr_port" {
  type              = "egress"
  protocol          = "tcp"
  cidr_blocks       = [data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.cidr_block]
  to_port           = local.bgdc_dwx_nginx_target[local.environment]
  from_port         = local.bgdc_dwx_nginx_target[local.environment]
  security_group_id = data.terraform_remote_state.internal_compute.outputs.vpce_security_groups.nginx_asg_bgdc_dwx.id
}

resource "aws_security_group_rule" "allow_nginx_subnet_from_nlb_to_emr" {
  count                    = length(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.cidr_blocks)
  type                     = "ingress"
  description              = "Allow nginx subnets"
  protocol                 = "tcp"
  from_port                = local.bgdc_dwx_nginx_target[local.environment]
  to_port                  = local.bgdc_dwx_nginx_target[local.environment]
  security_group_id        = aws_security_group.bgdc_master.id
  cidr_blocks              = [data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.cidr_blocks[count.index]]                             
}

data "aws_iam_policy_document" "ec2_nginx_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "dwx_bgdc_nginx_instance_role" {
  name               = "dwx-bgdc-nginx-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_instance_profile" "dwx_bgdc_nginx_instance_profile" {
  name     = "dwx-bgdc-nginx-instance-profile"
  role     = aws_iam_role.dwx_bgdc_nginx_instance_role.id
}

resource "aws_iam_role_policy_attachment" "ec2_nginx_for_ssm_attachment" {
  role       = aws_iam_role.dwx_bgdc_nginx_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "amazon_ssm_managed_instance_core_for_nginx" {
  role       = aws_iam_role.dwx_bgdc_nginx_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
