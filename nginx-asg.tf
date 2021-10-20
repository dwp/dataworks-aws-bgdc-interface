data "aws_ami" "bgdc_nginx_latest" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bgdc-nginx-ami-main-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [local.bgdc_account.test]
}

resource "aws_launch_configuration" "nginx_conf" {
  name_prefix     = "dwx-bgdc-nginx-"
  image_id        = data.aws_ami.bgdc_nginx_latest.id
  instance_type   = "t2.medium"
  security_groups = [aws_security_group.nginx-bgdc-dwx.id]
  iam_instance_profile = aws_iam_instance_profile.dwx_bgdc_nginx_instance_profile.arn
 
  
  user_data = templatefile("bootstrapBgdcDwxNginx.template", { BgdcDwxListener = local.bgdc_dwx_listener[local.environment], BgdcDwxNginxDns = "localhost", BgdcDwxNginxPort = local.bgdc_dwx_nginx_target[local.environment] })

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
  vpc_zone_identifier       = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids
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
  subnets            = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids


  enable_deletion_protection = false

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

resource "aws_lb" "dwx_bdgc_nginx_emr_nlb" {
  name               = "dwx-bgdc-nginx-emr-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids


  enable_deletion_protection = false

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


resource "aws_autoscaling_attachment" "asg_attachment_nginx_nlb" {
  autoscaling_group_name = aws_autoscaling_group.nginx_asg.id
  alb_target_group_arn   = aws_lb_target_group.dwx_bdgc_nginx_nlb_tg.id
}


resource "aws_vpc_endpoint_service" "bgdc_dwx_end_point_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.dwx_bdgc_nginx_nlb.arn]
  allowed_principals = ["arn:aws:iam::${local.bgdc_account.test}:root"]
  tags = {
    Name = "bgdc-dwx-endpoint-svc"
  }
}

output "bgdc_dwx_vpc_endpoint_service_name" {
  value = aws_vpc_endpoint_service.bgdc_dwx_end_point_service.service_name
}


resource "aws_security_group" "nginx-bgdc-dwx" {
  name                   = "nginx-bgdc-dwx-instances"
  description            = "Contains rules for nginx instances"
  revoke_rules_on_delete = true
  vpc_id                 = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
}


resource "aws_security_group_rule" "allow_http_from_target_group" {
  description              = "HTTP from target group"
  from_port                = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nginx-bgdc-dwx.id
  to_port                  = 80
  type                     = "ingress"
  cidr_blocks              = formatlist("%s/32", [for eni in data.aws_network_interface.dwx_bdgc_nlb_ni : eni.private_ip])
    
                             
}


data "aws_network_interface" "dwx_bdgc_nlb_ni" {
  for_each = toset(data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.ids)

  filter {
    name   = "description"
    values = ["ELB ${aws_lb.dwx_bdgc_nginx_nlb.arn_suffix}"]
  }

  filter {
    name   = "subnet-id"
    values = [each.value]
  }
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
