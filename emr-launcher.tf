variable "emr_launcher_zip" {
  type = map(string)

  default = {
    base_path = ""
    version   = ""
  }
}

resource "aws_lambda_function" "bgdc_emr_launcher" {
  filename      = "${var.emr_launcher_zip["base_path"]}/emr-launcher-${var.emr_launcher_zip["version"]}.zip"
  function_name = "bgdc_emr_launcher"
  role          = aws_iam_role.bgdc_emr_launcher_lambda_role.arn
  handler       = "emr_launcher/handler.handler"
  runtime       = "python3.7"
  source_code_hash = filebase64sha256(
    format(
      "%s/emr-launcher-%s.zip",
      var.emr_launcher_zip["base_path"],
      var.emr_launcher_zip["version"]
    )
  )
  publish = false
  timeout = 60

  environment {
    variables = {
      EMR_LAUNCHER_CONFIG_S3_BUCKET = data.terraform_remote_state.common.outputs.config_bucket.id
      EMR_LAUNCHER_CONFIG_S3_FOLDER = local.emr_config_s3_prefix
      EMR_LAUNCHER_LOG_LEVEL        = "debug"
    }
  }
  tags = merge(
    local.common_tags,
    {
      Name                  = "bgdc_emr_launcher"
      ProtectsSensitiveData = "False"
      Version               = var.emr_launcher_zip["version"]
    },
  )
  depends_on = [aws_cloudwatch_log_group.bgdc_emr_launcher]
}

resource "aws_iam_role" "bgdc_emr_launcher_lambda_role" {
  name               = "bgdc_emr_launcher_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.bgdc_emr_launcher_assume_policy.json
}

data "aws_iam_policy_document" "bgdc_emr_launcher_assume_policy" {
  statement {
    sid     = "BGDCEMRLauncherLambdaAssumeRolePolicy"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "bgdc_emr_launcher_read_s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::${data.terraform_remote_state.common.outputs.config_bucket.id}/${local.emr_config_s3_prefix}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [
      data.terraform_remote_state.common.outputs.config_bucket_cmk.arn
    ]
  }
}

data "aws_iam_policy_document" "bgdc_emr_launcher_runjobflow_policy" {
  statement {
    effect = "Allow"
    actions = [
      "elasticmapreduce:RunJobFlow",
    ]
    resources = [
      "*"
    ]
  }
}

data "aws_iam_policy_document" "bgdc_emr_launcher_pass_role_document" {
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::*:role/*"
    ]
  }
}

resource "aws_iam_policy" "bgdc_emr_launcher_read_s3_policy" {
  name        = "BGDCReadS3"
  description = "Allow BGDC to read from S3 bucket"
  policy      = data.aws_iam_policy_document.bgdc_emr_launcher_read_s3_policy.json
}

resource "aws_iam_policy" "bgdc_emr_launcher_runjobflow_policy" {
  name        = "BGDCRunJobFlow"
  description = "Allow BGDC to run job flow"
  policy      = data.aws_iam_policy_document.bgdc_emr_launcher_runjobflow_policy.json
}

resource "aws_iam_policy" "bgdc_emr_launcher_pass_role_policy" {
  name        = "BGDCPassRole"
  description = "Allow BGDC to pass role"
  policy      = data.aws_iam_policy_document.bgdc_emr_launcher_pass_role_document.json
}

resource "aws_iam_role_policy_attachment" "bgdc_emr_launcher_read_s3_attachment" {
  role       = aws_iam_role.bgdc_emr_launcher_lambda_role.name
  policy_arn = aws_iam_policy.bgdc_emr_launcher_read_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "bgdc_emr_launcher_runjobflow_attachment" {
  role       = aws_iam_role.bgdc_emr_launcher_lambda_role.name
  policy_arn = aws_iam_policy.bgdc_emr_launcher_runjobflow_policy.arn
}

resource "aws_iam_role_policy_attachment" "bgdc_emr_launcher_pass_role_attachment" {
  role       = aws_iam_role.bgdc_emr_launcher_lambda_role.name
  policy_arn = aws_iam_policy.bgdc_emr_launcher_pass_role_policy.arn
}

resource "aws_iam_role_policy_attachment" "bgdc_emr_launcher_policy_execution" {
  role       = aws_iam_role.bgdc_emr_launcher_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "bgdc_emr_launcher_getsecrets" {
  name        = "BGDCGetSecrets"
  description = "Allow BGDC Lambda function to get secrets"
  policy      = data.aws_iam_policy_document.bgdc_emr_launcher_getsecrets.json
}

data "aws_iam_policy_document" "bgdc_emr_launcher_getsecrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      data.terraform_remote_state.adg.outputs.metadata_store_users.bgdc.secret_arn,
    ]
  }
}

resource "aws_iam_role_policy_attachment" "bgdc_emr_launcher_getsecrets" {
  role       = aws_iam_role.bgdc_emr_launcher_lambda_role.name
  policy_arn = aws_iam_policy.bgdc_emr_launcher_getsecrets.arn
}

resource "aws_cloudwatch_log_group" "bgdc_emr_launcher" {
  name              = "/aws/lambda/bgdc_emr_launcher"
  retention_in_days = 180
  tags              = local.common_tags
}
