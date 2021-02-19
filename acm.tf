resource "aws_acm_certificate" "bgdc_interface" {
  for_each                  = local.emr_clusters
  certificate_authority_arn = data.terraform_remote_state.aws_certificate_authority.outputs.root_ca.arn
  domain_name               = "${local.emr_clusters[each.key]}.${local.env_prefix[local.environment]}${local.dataworks_domain_name}"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }
}

data "aws_iam_policy_document" "bgdc_interface" {
  for_each = local.emr_clusters
  statement {
    effect = "Allow"

    actions = [
      "acm:ExportCertificate",
    ]

    resources = [
      aws_acm_certificate.bgdc_interface[each.key].arn
    ]
  }
}

resource "aws_iam_policy" "bgdc_interface_acm" {
  for_each    = local.emr_clusters
  name        = "${each.key}_ACMExportBGDCCert"
  description = "Allow export of BGDC Interface certificate"
  policy      = data.aws_iam_policy_document.bgdc_interface[each.key].json
}
