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
  statement {
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = [
      data.terraform_remote_state.common.outputs.published_bucket.arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject*",
    ]

    resources = [
      "${data.terraform_remote_state.common.outputs.published_bucket.arn}/analytical-dataset/*",
    ]
  }

  statement {
    effect = "Allow"

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
  name        = "BGDCInterfaceReadParquet"
  description = "Allow reading of Analytical Dataset parquet files"
  policy      = data.aws_iam_policy_document.bgdc_read_parquet.json
}
