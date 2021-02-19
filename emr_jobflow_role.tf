data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "bgdc_interface" {
  for_each           = local.emr_clusters
  name               = each.key
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_instance_profile" "bgdc_interface" {
  for_each = local.emr_clusters
  name     = each.key
  role     = aws_iam_role.bgdc_interface[each.key].id
}

resource "aws_iam_role_policy_attachment" "ec2_for_ssm_attachment" {
  for_each   = local.emr_clusters
  role       = aws_iam_role.bgdc_interface[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "amazon_ssm_managed_instance_core" {
  for_each   = local.emr_clusters
  role       = aws_iam_role.bgdc_interface[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "bgdc_ebs_cmk" {
  for_each   = local.emr_clusters
  role       = aws_iam_role.bgdc_interface[each.key].name
  policy_arn = aws_iam_policy.bgdc_ebs_cmk_encrypt.arn
}

resource "aws_iam_role_policy_attachment" "bgdc_read_parquet" {
  for_each   = local.emr_clusters
  role       = aws_iam_role.bgdc_interface[each.key].name
  policy_arn = aws_iam_policy.bgdc_read_parquet[each.key].arn
}

resource "aws_iam_role_policy_attachment" "bgdc_interface_acm" {
  for_each   = local.emr_clusters
  role       = aws_iam_role.bgdc_interface[each.key].name
  policy_arn = aws_iam_policy.bgdc_interface_acm[each.key].arn
}

data "aws_iam_policy_document" "bgdc_interface_write_logs" {
  for_each = local.emr_clusters

  statement {
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = [
      data.terraform_remote_state.security-tools.outputs.logstore_bucket.arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject*",
      "s3:PutObject*",

    ]

    resources = [
      "${data.terraform_remote_state.security-tools.outputs.logstore_bucket.arn}/${local.s3_log_prefix[each.key]}",
    ]
  }
}

resource "aws_iam_policy" "bgdc_interface_write_logs" {
  for_each    = local.emr_clusters
  name        = "${each.key}_WriteLogs"
  description = "Allow writing of BGDC Interface logs"
  policy      = data.aws_iam_policy_document.bgdc_interface_write_logs[each.key].json
}

resource "aws_iam_role_policy_attachment" "bgdc_interface_write_logs" {
  for_each   = local.emr_clusters
  role       = aws_iam_role.bgdc_interface[each.key].name
  policy_arn = aws_iam_policy.bgdc_interface_write_logs[each.key].arn
}

data "aws_iam_policy_document" "bgdc_interface_config" {

  statement {
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = [
      data.terraform_remote_state.common.outputs.config_bucket.arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject*",
    ]

    resources = [
      "${data.terraform_remote_state.common.outputs.config_bucket.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject*",
    ]

    resources = [
      "${data.terraform_remote_state.common.outputs.config_bucket.arn}/component/bgdc*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
    ]

    resources = [
      "${data.terraform_remote_state.common.outputs.config_bucket_cmk.arn}",
    ]
  }
}

resource "aws_iam_policy" "bgdc_interface_read_config" {
  name        = "BGDCReadConfig"
  description = "Allow reading of BGD Interface config files"
  policy      = data.aws_iam_policy_document.bgdc_interface_config.json
}

resource "aws_iam_role_policy_attachment" "bgdc_interface_read_config" {
  for_each   = local.emr_clusters
  role       = aws_iam_role.bgdc_interface[each.key].name
  policy_arn = aws_iam_policy.bgdc_interface_read_config.arn
}

data "aws_iam_policy_document" "bgdc_interface_read_artefacts" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = [
      data.terraform_remote_state.management_mgmt.outputs.artefact_bucket.arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject*",
    ]

    resources = [
      "${data.terraform_remote_state.management_mgmt.outputs.artefact_bucket.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = [
      data.terraform_remote_state.management_mgmt.outputs.artefact_bucket.cmk_arn,
    ]
  }
}

resource "aws_iam_policy" "bgdc_interface_read_artefacts" {
  name        = "BGDCInterfaceReadArtefacts"
  description = "Allow reading of BGDC Interface software artefacts"
  policy      = data.aws_iam_policy_document.bgdc_interface_read_artefacts.json
}

resource "aws_iam_role_policy_attachment" "bgdc_interface_read_artefacts" {
  for_each   = local.emr_clusters
  role       = aws_iam_role.bgdc_interface[each.key].name
  policy_arn = aws_iam_policy.bgdc_interface_read_artefacts.arn
}

data "aws_iam_policy_document" "bgdc_interface_read_dynamodb" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:ConditionCheckItem",
      "dynamodb:GetItem",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:DescribeTable",
    ]

    resources = [
      "arn:aws:dynamodb:${var.region}:${local.account[local.environment]}:table/${local.emrfs_metadata_tablename}",
      "arn:aws:dynamodb:${var.region}:${local.account[local.environment]}:table/${local.data_pipeline_metadata}"
    ]
  }
}

resource "aws_iam_policy" "bgdc_interface_read_dynamodb" {
  name        = "BGDCInterfaceDynamoDB"
  description = "Allows read access to ADG's EMRFS DynamoDB table"
  policy      = data.aws_iam_policy_document.bgdc_interface_read_dynamodb.json
}

resource "aws_iam_role_policy_attachment" "bgdc_interface_read_dynamodb" {
  for_each   = local.emr_clusters
  role       = aws_iam_role.bgdc_interface[each.key].name
  policy_arn = aws_iam_policy.bgdc_interface_read_dynamodb.arn
}

data "aws_iam_policy_document" "bgdc_interface_various" {
  for_each = local.emr_clusters
  statement {
    effect = "Allow"

    actions = [
      "ec2:ModifyInstanceMetadataOptions",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${local.account[local.environment]}:instance/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:RegisterTargets",
    ]

    resources = [aws_lb_target_group.bgdc_interface_hive[each.key].arn]
  }
}

resource "aws_iam_policy" "bgdc_interface_metadata_change" {
  for_each    = local.emr_clusters
  name        = "${each.key}_MetadataOptions"
  description = "Allow editing of Metadata Options"
  policy      = data.aws_iam_policy_document.bgdc_interface_various[each.key].json
}

resource "aws_iam_role_policy_attachment" "bgdc_interface_metadata_change" {
  for_each   = local.emr_clusters
  role       = aws_iam_role.bgdc_interface[each.key].name
  policy_arn = aws_iam_policy.bgdc_interface_metadata_change[each.key].arn
}

