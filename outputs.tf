output "bgdc_common_sg_id" {
  value = aws_security_group.bgdc_common.id
}

output "bgdc_dwx_vpc_endpoint_service_name" {
  value = aws_vpc_endpoint_service.bgdc_dwx_end_point_service.service_name
}