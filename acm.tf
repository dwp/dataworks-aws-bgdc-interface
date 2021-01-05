resource "aws_acm_certificate" "bgdc_interface" {
  certificate_authority_arn = data.terraform_remote_state.aws_certificate_authority.outputs.root_ca.arn
  domain_name               = "bgdc-interface.${local.env_prefix[local.environment]}${local.dataworks_domain_name}"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }
}

data "aws_iam_policy_document" "bgdc_interface" {
  statement {
    effect = "Allow"

    actions = [
      "acm:ExportCertificate",
    ]

    resources = [
      aws_acm_certificate.bgdc_interface.arn
    ]
  }
}

resource "aws_iam_policy" "bgdc_interface_acm" {
  name        = "ACMExportBGDCCert"
  description = "Allow export of BGDC Interface certificate"
  policy      = data.aws_iam_policy_document.bgdc_interface.json
}
