resource "aws_vpc_peering_connection" "peer_with_bgdc" {
  count         = local.peer_with_bgdc[local.environment] ? 1 : 0
  vpc_id        = module.profiling_vpc.vpc.id
  peer_vpc_id   = local.peer_with_bgdc_vpc_id[local.environment]
  peer_owner_id = local.peer_with_bgdc_owner_id[local.environment]
  auto_accept   = false

  tags = merge(
    local.common_tags,
    {
      "Name" = "Profiling to BGDC"
    },
  )
}
