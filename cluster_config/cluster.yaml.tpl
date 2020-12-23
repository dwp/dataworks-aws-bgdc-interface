---
Applications:
- Name: "Spark"
- Name: "Ganglia"
- Name: "Hive"
CustomAmiId: "${ami_id}"
EbsRootVolumeSize: 100
LogUri: "s3://${s3_log_bucket}/${s3_log_prefix}"
Name: "bgdc-interface"
ReleaseLabel: "emr-${emr_release}"
SecurityConfiguration: "${security_configuration}"
ScaleDownBehavior: "TERMINATE_AT_TASK_COMPLETION"
ServiceRole: "${service_role}"
JobFlowRole: "${instance_profile}"
VisibleToAllUsers: True
Tags:
- Key: "Persistence"
  Value: "Ignore"
- Key: "Owner"
  Value: "dataworks platform"
- Key: "AutoShutdown"
  Value: "False"
- Key: "CreatedBy"
  Value: "emr-launcher-bgdc"
- Key: "SSMEnabled"
  Value: "True"
- Key: "Environment"
  Value: "development"
- Key: "Application"
  Value: "dataworks-aws-bgdc-interface"
- Key: "Name"
  Value: "dataworks-aws-bgdc-interface"
