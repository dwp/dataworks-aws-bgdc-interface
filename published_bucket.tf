data "aws_iam_user" "breakglass" {
  user_name = "breakglass"
}

data "aws_iam_role" "ci" {
  name = "ci"
}

data "aws_iam_role" "administrator" {
  name = "administrator"
}

data "aws_iam_role" "aws_config" {
  name = "aws_config"
}


data "aws_iam_policy_document" "bgdc_read_parquet" {
  for_each = local.emr_clusters
  statement {
    effect = local.parquet_permissions[each.key]

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = [
      data.terraform_remote_state.common.outputs.published_bucket.arn,
    ]
  }

  statement {
    effect = local.parquet_permissions[each.key]

    actions = [
      "s3:GetObject*",
    ]

    resources = [
      "${data.terraform_remote_state.common.outputs.published_bucket.arn}/analytical-dataset/*",
    ]
  }

  statement {
    effect = local.parquet_permissions[each.key]

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = [
      data.terraform_remote_state.common.outputs.published_bucket_cmk.arn,
    ]
  }
}

resource "aws_iam_policy" "bgdc_read_parquet" {
  for_each    = local.emr_clusters
  name        = "${each.key}_InterfaceReadParquet"
  description = "Control access to Analytical Dataset parquet files"
  policy      = data.aws_iam_policy_document.bgdc_read_parquet[each.key].json
}
