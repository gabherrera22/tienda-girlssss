#!/usr/bin/env bash
# Crea (o reutiliza) la instancia EC2 donde corre el sistema en la nube:
# grupo de seguridad, instancia con Docker, rol LabInstanceProfile e IP elastica.
# Es idempotente.
set -euo pipefail
export MSYS_NO_PATHCONV=1

REGION="${AWS_REGION:-us-east-1}"
TIPO="${EC2_TIPO:-t3.medium}"
LLAVE="${EC2_LLAVE:-vockey}"
NOMBRE="tienda-backend"

VPC=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)

echo ">> Grupo de seguridad tienda-sg"
SG=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters Name=group-name,Values=tienda-sg Name=vpc-id,Values="$VPC" \
  --query 'SecurityGroups[0].GroupId' --output text)
if [ "$SG" = "None" ]; then
  SG=$(aws ec2 create-security-group --region "$REGION" --group-name tienda-sg \
    --description "Tienda: SSH y HTTP" --vpc-id "$VPC" --query GroupId --output text)
fi
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG" \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 >/dev/null 2>&1 || true
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null 2>&1 || true

echo ">> Instancia $NOMBRE"
ID=$(aws ec2 describe-instances --region "$REGION" \
  --filters Name=tag:Name,Values="$NOMBRE" Name=instance-state-name,Values=pending,running,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text)

if [ -z "$ID" ]; then
  AMI=$(aws ssm get-parameter --region "$REGION" \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query Parameter.Value --output text)

  DATOS_USUARIO='#!/bin/bash
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
mkdir -p /opt/tienda
chown ec2-user:ec2-user /opt/tienda'

  ID=$(aws ec2 run-instances --region "$REGION" \
    --image-id "$AMI" --instance-type "$TIPO" --key-name "$LLAVE" \
    --security-group-ids "$SG" \
    --iam-instance-profile Name=LabInstanceProfile \
    --metadata-options "HttpTokens=required,HttpPutResponseHopLimit=2,HttpEndpoint=enabled" \
    --block-device-mappings "DeviceName=/dev/xvda,Ebs={VolumeSize=20,VolumeType=gp3}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NOMBRE}]" \
    --user-data "$DATOS_USUARIO" \
    --query 'Instances[0].InstanceId' --output text)
  echo "   Creada: $ID"
else
  echo "   Ya existe: $ID"
  aws ec2 start-instances --region "$REGION" --instance-ids "$ID" >/dev/null 2>&1 || true
fi

aws ec2 wait instance-running --region "$REGION" --instance-ids "$ID"

echo ">> IP elastica"
EIP=$(aws ec2 describe-addresses --region "$REGION" --filters Name=tag:Name,Values=tienda-eip \
  --query 'Addresses[0].AllocationId' --output text)
if [ "$EIP" = "None" ]; then
  EIP=$(aws ec2 allocate-address --region "$REGION" --domain vpc \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=tienda-eip}]" \
    --query AllocationId --output text)
fi
aws ec2 associate-address --region "$REGION" --instance-id "$ID" --allocation-id "$EIP" \
  --allow-reassociation >/dev/null
IP=$(aws ec2 describe-addresses --region "$REGION" --allocation-ids "$EIP" \
  --query 'Addresses[0].PublicIp' --output text)

echo ">> Listo"
echo "   Instancia: $ID"
echo "   IP publica: $IP"
echo "   Conexion:   ssh -i ~/.ssh/labsuser.pem ec2-user@$IP"
