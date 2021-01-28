data "archive_file" "site_xml_archive" {
  type        = "zip"
  output_path = "tmp/bgdc-interface-site-xml.zip"
  source_dir  = "site_xml"
}

resource "aws_s3_bucket_object" "site_xml_archive" {
  bucket = data.terraform_remote_state.common.outputs.config_bucket.id
  key    = "/bgdc-interface/bgdc-interface-site-xml.zip"
  source = data.archive_file.site_xml_archive.output_path
}
