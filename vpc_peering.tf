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

resource "aws_route" "peer_with_bgdc" {
  count                     = local.peer_with_bgdc[local.environment] ? length(local.peer_with_bgdc_source_cidrs[local.environment]) : 0
  route_table_id            = aws_route_table.profiling.id
  destination_cidr_block    = local.peer_with_bgdc_source_cidrs[local.environment][count.index]
  vpc_peering_connection_id = aws_vpc_peering_connection.peer_with_bgdc[0].id
}
