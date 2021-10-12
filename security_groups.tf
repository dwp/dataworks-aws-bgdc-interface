resource "aws_security_group" "bgdc_master" {
  name                   = "BGDC Master"
  description            = "Contains rules for BGDC master nodes; most rules are injected by EMR, not managed by TF"
  revoke_rules_on_delete = true
  vpc_id                 = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
}

resource "aws_security_group" "bgdc_slave" {
  name                   = "BGDC Slave"
  description            = "Contains rules for BGDC slave nodes; most rules are injected by EMR, not managed by TF"
  revoke_rules_on_delete = true
  vpc_id                 = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
}

resource "aws_security_group" "bgdc_common" {
  name                   = "BGDC Common"
  description            = "Contains rules for both BGDC master and BGDC slave nodes"
  revoke_rules_on_delete = true
  vpc_id                 = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
}

resource "aws_security_group" "bgdc_emr_service" {
  name                   = "BGDC EMR Service"
  description            = "Contains rules for EMR service when managing the BGDC cluster; rules are injected by EMR, not managed by TF"
  revoke_rules_on_delete = true
  vpc_id                 = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
}

resource "aws_security_group_rule" "egress_https_to_vpc_endpoints" {
  description              = "HTTPS traffic to VPC endpoints"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bgdc_common.id
  to_port                  = 443
  type                     = "egress"
  source_security_group_id = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.interface_vpce_sg_id
}

resource "aws_security_group_rule" "ingress_https_vpc_endpoints_from_emr" {
  description              = "HTTPS traffic from BGDC EMR cluster"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.interface_vpce_sg_id
  to_port                  = 443
  type                     = "ingress"
  source_security_group_id = aws_security_group.bgdc_common.id
}

resource "aws_security_group_rule" "egress_https_s3_endpoint" {
  description       = "HTTPS access to S3 via its endpoint"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.terraform_remote_state.internal_compute.outputs.vpc.vpc.prefix_list_ids.s3]
  security_group_id = aws_security_group.bgdc_common.id
}

resource "aws_security_group_rule" "egress_http_s3_endpoint" {
  description       = "HTTP access to S3 via its endpoint (YUM)"
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  prefix_list_ids   = [data.terraform_remote_state.internal_compute.outputs.vpc.vpc.prefix_list_ids.s3]
  security_group_id = aws_security_group.bgdc_common.id
}

resource "aws_security_group_rule" "egress_https_dynamodb_endpoint" {
  description       = "HTTPS access to DynamoDB via its endpoint (EMRFS)"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.terraform_remote_state.internal_compute.outputs.vpc.vpc.prefix_list_ids.dynamodb]
  security_group_id = aws_security_group.bgdc_common.id
}

resource "aws_security_group_rule" "egress_internet_proxy" {
  description              = "Internet access via the proxy (for ACM-PCA)"
  type                     = "egress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.internal_compute.outputs.internet_proxy.sg
  security_group_id        = aws_security_group.bgdc_common.id
}

resource "aws_security_group_rule" "ingress_internet_proxy" {
  description              = "proxy access from BGDC"
  type                     = "ingress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bgdc_common.id
  security_group_id        = data.terraform_remote_state.internal_compute.outputs.internet_proxy.sg
}

resource "aws_security_group_rule" "egress_bgdc_to_dks" {
  description       = "requests to the DKS"
  type              = "egress"
  from_port         = 8443
  to_port           = 8443
  protocol          = "tcp"
  cidr_blocks       = data.terraform_remote_state.crypto.outputs.dks_subnet.cidr_blocks
  security_group_id = aws_security_group.bgdc_common.id
}

resource "aws_security_group_rule" "ingress_to_dks" {
  provider          = aws.crypto
  description       = "inbound requests to DKS from bgdc"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 8443
  to_port           = 8443
  cidr_blocks       = data.terraform_remote_state.internal_compute.outputs.bgdc_subnet.cidr_blocks
  security_group_id = data.terraform_remote_state.crypto.outputs.dks_sg_id[local.environment]
}

# https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-man-sec-groups.html#emr-sg-elasticmapreduce-sa-private
resource "aws_security_group_rule" "emr_service_ingress_master" {
  description              = "EMR master nodes to EMR service"
  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bgdc_master.id
  security_group_id        = aws_security_group.bgdc_emr_service.id
}


# The EMR service will automatically add the ingress equivalent of this rule,
# but doesn't inject this egress counterpart
resource "aws_security_group_rule" "emr_master_to_core_egress_tcp" {
  description              = "master nodes to core nodes"
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bgdc_slave.id
  security_group_id        = aws_security_group.bgdc_master.id
}

# The EMR service will automatically add the ingress equivalent of this rule,
# but doesn't inject this egress counterpart
resource "aws_security_group_rule" "emr_core_to_master_egress_tcp" {
  description              = "core nodes to master nodes"
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bgdc_master.id
  security_group_id        = aws_security_group.bgdc_slave.id
}

# The EMR service will automatically add the ingress equivalent of this rule,
# but doesn't inject this egress counterpart
resource "aws_security_group_rule" "emr_core_to_core_egress_tcp" {
  description       = "core nodes to other core nodes"
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.bgdc_slave.id
}

# The EMR service will automatically add the ingress equivalent of this rule,
# but doesn't inject this egress counterpart
resource "aws_security_group_rule" "emr_master_to_core_egress_udp" {
  description              = "master nodes to core nodes"
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "udp"
  source_security_group_id = aws_security_group.bgdc_slave.id
  security_group_id        = aws_security_group.bgdc_master.id
}

# The EMR service will automatically add the ingress equivalent of this rule,
# but doesn't inject this egress counterpart
resource "aws_security_group_rule" "emr_core_to_master_egress_udp" {
  description              = "core nodes to master nodes"
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "udp"
  source_security_group_id = aws_security_group.bgdc_master.id
  security_group_id        = aws_security_group.bgdc_slave.id
}

# The EMR service will automatically add the ingress equivalent of this rule,
# but doesn't inject this egress counterpart
resource "aws_security_group_rule" "emr_core_to_core_egress_udp" {
  description       = "core nodes to other core nodes"
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "udp"
  self              = true
  security_group_id = aws_security_group.bgdc_slave.id
}

resource "aws_security_group_rule" "bgdc_to_hive_metastore" {
  description              = "BGDC to Hive Metastore"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bgdc_common.id
  security_group_id        = data.terraform_remote_state.adg.outputs.hive_metastore.security_group.id
}

resource "aws_security_group_rule" "hive_metastore_from_bgdc" {
  description              = "Hive Metastore from BGDC"
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bgdc_common.id
  source_security_group_id = data.terraform_remote_state.adg.outputs.hive_metastore.security_group.id
}

resource "aws_security_group_rule" "bgdc_to_hive_metastore_v2" {
  description              = "BGDC to Hive Metastore"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bgdc_common.id
  security_group_id        = data.terraform_remote_state.internal_compute.outputs.hive_metastore_v2.security_group.id
}

resource "aws_security_group_rule" "hive_metastore_v2_from_bgdc" {
  description              = "Hive Metastore from BGDC"
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bgdc_common.id
  source_security_group_id = data.terraform_remote_state.internal_compute.outputs.hive_metastore_v2.security_group.id
}

output "bgdc_common_sg_id" {
  value = aws_security_group.bgdc_common.id
}
