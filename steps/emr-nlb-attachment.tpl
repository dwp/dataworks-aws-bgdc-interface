export AWS_DEFAULT_REGION=${aws_default_region}

FULL_PROXY="${full_proxy}"
FULL_NO_PROXY="${full_no_proxy}"
export http_proxy="$FULL_PROXY"
export HTTP_PROXY="$FULL_PROXY"
export https_proxy="$FULL_PROXY"
export HTTPS_PROXY="$FULL_PROXY"
export no_proxy="$FULL_NO_PROXY"
export NO_PROXY="$FULL_NO_PROXY"

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws elbv2 register-targets --target-group-arn ${target_group_arn} --targets Id=$INSTANCE_ID
