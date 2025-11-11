#!/bin/bash

# AWS CI/CD Infrastructure Setup Script
# This script sets up the necessary AWS resources for the CI/CD pipeline

set -e

# Configuration
AWS_REGION=${1:-us-east-1}
ECR_REPO_NAME="aws-cicd-webapp"
EC2_INSTANCE_TYPE="t3.medium"
KEY_NAME="cicd-key-pair"
SECURITY_GROUP_NAME="cicd-sg"
INSTANCE_PROFILE_NAME="EC2-ECR-Profile"
IAM_ROLE_NAME="EC2-ECR-Role"

echo "Setting up AWS infrastructure in region: $AWS_REGION"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
if ! command_exists aws; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

if ! command_exists jq; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

# 1. Create ECR Repository
echo "Creating ECR Repository..."
if aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo "ECR Repository '$ECR_REPO_NAME' already exists"
    ECR_REPO_URI=$(aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" | jq -r '.repositories[0].repositoryUri')
else
    ECR_REPO_URI=$(aws ecr create-repository --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION" | jq -r '.repository.repositoryUri')
    echo "Created ECR Repository: $ECR_REPO_URI"
fi

# 2. Create IAM Role for EC2 instance
echo "Creating IAM Role for EC2..."
if aws iam get-role --role-name "$IAM_ROLE_NAME" 2>/dev/null; then
    echo "IAM Role '$IAM_ROLE_NAME' already exists"
else
    aws iam create-role --role-name "$IAM_ROLE_NAME" \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"Service": "ec2.amazonaws.com"},
                    "Action": "sts:AssumeRole"
                }
            ]
        }'

    # Attach policies
    aws iam attach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
    aws iam attach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
    aws iam attach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

    # Create instance profile
    aws iam create-instance-profile --instance-profile-name "$INSTANCE_PROFILE_NAME"
    aws iam add-role-to-instance-profile --instance-profile-name "$INSTANCE_PROFILE_NAME" --role-name "$IAM_ROLE_NAME"

    echo "Created IAM Role and Instance Profile"
fi

# 3. Create Key Pair
echo "Creating Key Pair..."
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo "Key Pair '$KEY_NAME' already exists"
else
    # Create private key file
    PRIVATE_KEY_FILE="${KEY_NAME}.pem"
    aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$AWS_REGION" --query 'KeyMaterial' --output text > "$PRIVATE_KEY_FILE"
    chmod 400 "$PRIVATE_KEY_FILE"
    echo "Created Key Pair: $KEY_NAME (private key saved to $PRIVATE_KEY_FILE)"
fi

# 4. Create Security Group
echo "Creating Security Group..."
VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=isDefault,Values=true" | jq -r '.Vpcs[0].VpcId')

if aws ec2 describe-security-groups --group-names "$SECURITY_GROUP_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo "Security Group '$SECURITY_GROUP_NAME' already exists"
    SG_ID=$(aws ec2 describe-security-groups --group-names "$SECURITY_GROUP_NAME" --region "$AWS_REGION" | jq -r '.SecurityGroups[0].GroupId')
else
    SG_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "Security group for CI/CD instance" --vpc-id "$VPC_ID" --region "$AWS_REGION" | jq -r '.GroupId')

    # Add inbound rules
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$AWS_REGION"

    echo "Created Security Group: $SG_ID"
fi

# 5. Create EC2 Instance
echo "Creating EC2 Instance..."
USER_DATA_SCRIPT=$(cat <<'EOF'
#!/bin/bash
yum update -y
yum install -y docker git
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install CloudWatch Agent
yum install -y amazon-cloudwatch-agent

# Create application directory
mkdir -p /opt/app
chown ec2-user:ec2-user /opt/app

# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

EOF
)

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ami-0c55b159cbfafe1f0 \
    --instance-type "$EC2_INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile Name="$INSTANCE_PROFILE_NAME" \
    --user-data "$USER_DATA_SCRIPT" \
    --region "$AWS_REGION" \
    --count 1 \
    | jq -r '.Instances[0].InstanceId')

echo "Created EC2 Instance: $INSTANCE_ID"

# Wait for instance to be running
echo "Waiting for instance to be in running state..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" | jq -r '.Reservations[0].Instances[0].PublicIpAddress')

echo ""
echo "=================================="
echo "Infrastructure Setup Complete!"
echo "=================================="
echo "ECR Repository: $ECR_REPO_URI"
echo "EC2 Instance ID: $INSTANCE_ID"
echo "EC2 Public IP: $PUBLIC_IP"
echo "SSH Command: ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo "Application URL: http://$PUBLIC_IP:3000"
echo "=================================="

# Save configuration
cat > infrastructure-config.json << EOF
{
    "aws_region": "$AWS_REGION",
    "ecr_repository_uri": "$ECR_REPO_URI",
    "ec2_instance_id": "$INSTANCE_ID",
    "ec2_public_ip": "$PUBLIC_IP",
    "key_pair_name": "$KEY_NAME",
    "security_group_id": "$SG_ID",
    "iam_role_name": "$IAM_ROLE_NAME"
}
EOF

echo "Configuration saved to infrastructure-config.json"