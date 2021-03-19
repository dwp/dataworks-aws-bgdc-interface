export AWS_DEFAULT_REGION=${aws_default_region}

FULL_PROXY="${full_proxy}"
FULL_NO_PROXY="${full_no_proxy}"
export http_proxy="$FULL_PROXY"
export HTTP_PROXY="$FULL_PROXY"
export https_proxy="$FULL_PROXY"
export HTTPS_PROXY="$FULL_PROXY"
export no_proxy="$FULL_NO_PROXY"
export NO_PROXY="$FULL_NO_PROXY"

sudo mkdir -p /opt/ghostunnel
sudo mkdir -p /var/log/ghostunnel

aws s3 cp "${ghostunnel_service_script_name}"                          ~/
aws s3 cp s3://${artefact_bucket}/ghostunnel/${ghostunnel_binary_name} ~/

sudo mv ~/ghostunnel_service        /etc/init.d/
sudo mv ~/${ghostunnel_binary_name} /opt/ghostunnel/ghostunnel

sudo sh -c "cat /etc/pki/tls/private/${private_key_alias}.key > /opt/ghostunnel/bgdc_interface.pem"
sudo sh -c "echo '' >> /opt/ghostunnel/bgdc_interface.pem"
sudo sh -c "cat /etc/pki/tls/certs/${private_key_alias}.crt >> /opt/ghostunnel/bgdc_interface.pem"
sudo cp /etc/pki/ca-trust/source/anchors/bgdc_ca.pem /opt/ghostunnel/

sudo sh -c "echo '/opt/ghostunnel/ghostunnel server --listen 0.0.0.0:10443 --target localhost:10000 \
  --keystore /opt/ghostunnel/bgdc_interface.pem \
  --cacert /opt/ghostunnel/bgdc_ca.pem  --allow-all' > /opt/ghostunnel/ghostunnel.sh"
sudo chown -R hadoop:hadoop /opt/ghostunnel
sudo chown hadoop:hadoop /var/log/ghostunnel
sudo chown root:root /etc/init.d/ghostunnel_service
sudo chmod +x /etc/init.d/ghostunnel_service
sudo chmod +x /opt/ghostunnel/ghostunnel
sudo chmod +x /opt/ghostunnel/ghostunnel.sh

sudo chkconfig --add ghostunnel_service
sudo chkconfig ghostunnel_service on
sudo service ghostunnel_service start

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws elbv2 register-targets --target-group-arn ${target_group_arn} --targets Id=$INSTANCE_ID

if [[ "${register_in_tactical}" = "true" ]]; then
  aws elbv2 register-targets --target-group-arn ${tactical_target_group_arn} --targets Id=$INSTANCE_ID
fi

