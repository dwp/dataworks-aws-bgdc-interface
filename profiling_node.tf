resource "aws_acm_certificate" "profiling_node" {
  certificate_authority_arn = data.terraform_remote_state.aws_certificate_authority.outputs.root_ca.arn
  domain_name               = local.profiling_node_dns_name

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }
}

data "aws_iam_policy_document" "profiling_node_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "profiling_node" {
  name                 = "profiling_node"
  assume_role_policy   = data.aws_iam_policy_document.profiling_node_policy.json
  max_session_duration = local.iam_role_max_session_timeout_seconds
  tags                 = local.common_tags
}

resource "aws_iam_instance_profile" "profiling_node" {
  name = "profiling_node"
  role = aws_iam_role.profiling_node.name
}

data "aws_iam_policy_document" "profiling_node_main" {
  statement {
    sid    = "AllowACM"
    effect = "Allow"

    actions = [
      "acm:*Certificate",
    ]

    resources = [
    aws_acm_certificate.profiling_node.arn]
  }

  statement {
    sid    = "GetPublicCerts"
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
    data.terraform_remote_state.aws_certificate_authority.outputs.public_cert_bucket.arn]
  }

  statement {
    sid    = "AllowUseDefaultEbsCmk"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = [
    data.terraform_remote_state.security-tools.outputs.ebs_cmk.arn]
  }

  statement {
    effect = "Allow"
    sid    = "AllowAccessToConfigBucket"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [
    data.terraform_remote_state.common.outputs.config_bucket.arn]
  }

  statement {
    effect = "Allow"
    sid    = "AllowAccessToConfigBucketObjects"

    actions = [
    "s3:GetObject"]

    resources = [
    "${data.terraform_remote_state.common.outputs.config_bucket.arn}/*"]
  }

  statement {
    sid    = "AllowKMSDecryptionOfS3BucketObj"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = [
    data.terraform_remote_state.common.outputs.config_bucket_cmk.arn]
  }

  statement {
    sid    = "AllowAccessToArtefactBucket"
    effect = "Allow"
    actions = [
    "s3:GetBucketLocation"]
    resources = [
    data.terraform_remote_state.management_mgmt.outputs.artefact_bucket.arn]
  }

  statement {
    sid    = "AllowPullFromArtefactBucket"
    effect = "Allow"
    actions = [
    "s3:GetObject"]
    resources = [
    "${data.terraform_remote_state.management_mgmt.outputs.artefact_bucket.arn}/*"]
  }

  statement {
    sid    = "AllowDecryptArtefactBucket"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = [
    data.terraform_remote_state.management_mgmt.outputs.artefact_bucket.cmk_arn]
  }
}

resource "aws_iam_policy" "profiling_node_main" {
  name        = "profiling_node_emr"
  description = "Policy to allow access to EMR"
  policy      = data.aws_iam_policy_document.profiling_node_main.json
}

resource "aws_iam_role_policy_attachment" "profiling_node_main" {
  role       = aws_iam_role.profiling_node.name
  policy_arn = aws_iam_policy.profiling_node_main.arn
}

resource "aws_iam_role_policy_attachment" "profiling_node_cwasp" {
  role       = aws_iam_role.profiling_node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "profiling_node_ssm" {
  role       = aws_iam_role.profiling_node.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_launch_template" "profiling_node" {
  name_prefix                          = "profiling_node_"
  image_id                             = var.profiling_node_ami_id
  instance_type                        = local.profiling_node_ec2_size[local.environment]
  vpc_security_group_ids               = [aws_security_group.profiling_node.id]
  user_data                            = base64encode(data.template_file.profiling_node.rendered)
  instance_initiated_shutdown_behavior = "terminate"

  iam_instance_profile {
    arn = aws_iam_instance_profile.profiling_node.arn
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 128
      volume_type           = "io1"
      iops                  = "2000"
      delete_on_termination = true
      encrypted             = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "profiling_node",
      Persistence = "Ignore"
    },
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name        = "profiling_node",
        Persistence = "Ignore"
      },
    )
  }
}

resource "aws_autoscaling_group" "profiling_node" {
  name                      = aws_launch_template.profiling_node.name
  min_size                  = 0
  desired_capacity          = 1
  max_size                  = 1
  health_check_grace_period = 600
  health_check_type         = "EC2"
  force_delete              = true
  suspended_processes       = ["AZRebalance"]
  vpc_zone_identifier       = aws_subnet.profiling.*.id

  lifecycle {
    create_before_destroy = true
  }

  launch_template {
    id      = aws_launch_template.profiling_node.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(
      local.common_tags,
      { Name         = "profiling_node-${local.environment}",
        AutoShutdown = "False",
        SSMEnabled   = local.asg_ssmenabled[local.environment],
        Persistence  = "Ignore",
      },
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

data "template_file" "profiling_node" {
  template = file("profiling_node_userdata.tpl")

  vars = {
    acm_cert_arn          = aws_acm_certificate.profiling_node.arn
    private_key_alias     = local.environment
    truststore_aliases    = local.truststore_aliases[local.environment]
    truststore_certs      = local.truststore_certs[local.environment]
    internet_proxy        = aws_vpc_endpoint.internet_proxy.dns_entry[0].dns_name
    non_proxied_endpoints = join(",", module.profiling_vpc.no_proxy_list)
    s3_artefact_bucket_id = data.terraform_remote_state.management_mgmt.outputs.artefact_bucket.id
    s3_scripts_bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
    environment_name      = local.environment
  }
}

resource "aws_security_group" "profiling_node" {
  name        = "profiling_node"
  description = "Control access to and from the hbase-to-mongo-exporter Hosts"
  vpc_id      = module.profiling_vpc.vpc.id
  tags        = local.common_tags
}

resource "aws_security_group_rule" "profiling_node_egress_internet_proxy" {
  description              = "profiling_node Host to Internet Proxy (for ACM-PCA)"
  type                     = "egress"
  source_security_group_id = aws_security_group.internet_proxy_endpoint.id
  protocol                 = "tcp"
  from_port                = 3128
  to_port                  = 3128
  security_group_id        = aws_security_group.profiling_node.id
}

resource "aws_security_group_rule" "profiling_node_ingress_internet_proxy" {
  description              = "Allow proxy access from profiling_node"
  type                     = "ingress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.profiling_node.id
  security_group_id        = aws_security_group.internet_proxy_endpoint.id
}

resource "aws_security_group_rule" "profiling_node_egress_s3" {
  description       = "Allow profiling_node to reach S3"
  type              = "egress"
  prefix_list_ids   = [module.profiling_vpc.prefix_list_ids.s3]
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.profiling_node.id
}

resource "aws_security_group_rule" "profiling_node_egress_s3_http" {
  description       = "Allow profiling_node to reach S3"
  type              = "egress"
  prefix_list_ids   = [module.profiling_vpc.prefix_list_ids.s3]
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  security_group_id = aws_security_group.profiling_node.id
}

resource "aws_security_group_rule" "profiling_node_to_hive" {
  description              = "Profiling node to Hive endpoint"
  type                     = "egress"
  from_port                = 10443
  to_port                  = 10443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.profiling_node.id
  source_security_group_id = aws_security_group.bgdc_interface_vpce.id
}

resource "aws_security_group_rule" "hive_from_profiling_node" {
  description              = "Profiling node to Hive endpoint"
  type                     = "ingress"
  from_port                = 10443
  to_port                  = 10443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bgdc_interface_vpce.id
  source_security_group_id = aws_security_group.profiling_node.id
}

# Allow Informatica EDC intra-domain traffic
resource "aws_security_group_rule" "profiling_node_rds" {
  count             = local.peer_with_bgdc[local.environment] ? 1 : 0
  description       = "Profiling node to Informatica Oracle"
  type              = "egress"
  from_port         = 1521
  to_port           = 1521
  protocol          = "tcp"
  security_group_id = aws_security_group.profiling_node.id
  cidr_blocks       = local.peer_with_bgdc_source_cidrs[local.environment]
}

resource "aws_security_group_rule" "profiling_node_intradomain_secure" {
  count             = local.peer_with_bgdc[local.environment] ? 1 : 0
  description       = "Profiling node intradomain"
  type              = "ingress"
  from_port         = 8443
  to_port           = 8443
  protocol          = "tcp"
  security_group_id = aws_security_group.profiling_node.id
  cidr_blocks       = local.peer_with_bgdc_source_cidrs[local.environment]
}

resource "aws_security_group_rule" "profiling_node_intradomain_dis_in" {
  count             = local.peer_with_bgdc[local.environment] ? 1 : 0
  description       = "Profiling node intradomain Data Integration Service"
  type              = "ingress"
  from_port         = 8095
  to_port           = 8095
  protocol          = "tcp"
  security_group_id = aws_security_group.profiling_node.id
  cidr_blocks       = local.peer_with_bgdc_source_cidrs[local.environment]
}

resource "aws_security_group_rule" "profiling_node_intradomain_dis2_in" {
  count             = local.peer_with_bgdc[local.environment] ? 1 : 0
  description       = "Profiling node intradomain Data Integration Service"
  type              = "ingress"
  from_port         = 8195
  to_port           = 8195
  protocol          = "tcp"
  security_group_id = aws_security_group.profiling_node.id
  cidr_blocks       = local.peer_with_bgdc_source_cidrs[local.environment]
}

resource "aws_security_group_rule" "profiling_node_intradomain_static_in" {
  count             = local.peer_with_bgdc[local.environment] ? 1 : 0
  description       = "Profiling node intradomain"
  type              = "ingress"
  from_port         = 6005
  to_port           = 6009
  protocol          = "tcp"
  security_group_id = aws_security_group.profiling_node.id
  cidr_blocks       = local.peer_with_bgdc_source_cidrs[local.environment]
}

resource "aws_security_group_rule" "profiling_node_intradomain_dynamic_in" {
  count             = local.peer_with_bgdc[local.environment] ? 1 : 0
  description       = "Profiling node intradomain"
  type              = "ingress"
  from_port         = 6014
  to_port           = 6114
  protocol          = "tcp"
  security_group_id = aws_security_group.profiling_node.id
  cidr_blocks       = local.peer_with_bgdc_source_cidrs[local.environment]
}

resource "aws_security_group_rule" "profiling_node_intradomain_static_out" {
  count             = local.peer_with_bgdc[local.environment] ? 1 : 0
  description       = "Profiling node intradomain"
  type              = "egress"
  from_port         = 6005
  to_port           = 6009
  protocol          = "tcp"
  security_group_id = aws_security_group.profiling_node.id
  cidr_blocks       = local.peer_with_bgdc_source_cidrs[local.environment]
}

resource "aws_security_group_rule" "profiling_node_intradomain_dynamic_out" {
  count             = local.peer_with_bgdc[local.environment] ? 1 : 0
  description       = "Profiling node intradomain"
  type              = "egress"
  from_port         = 6014
  to_port           = 6114
  protocol          = "tcp"
  security_group_id = aws_security_group.profiling_node.id
  cidr_blocks       = local.peer_with_bgdc_source_cidrs[local.environment]
}

# Fits with log retention policy https://git.ucd.gpn.gov.uk/dip/aws-common-infrastructure/wiki/Audit-Logging#log-retention-policy
resource "aws_cloudwatch_log_group" "profiling_node" {
  name              = local.cw_agent_profiling_node_log_group_name
  retention_in_days = 180
  tags              = local.common_tags
}
