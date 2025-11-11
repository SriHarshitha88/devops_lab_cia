#!/bin/bash

# Deployment script for AWS EC2
# This script runs on the EC2 instance to deploy the new Docker image

set -e

# Configuration
DOCKER_IMAGE=${1:-"aws-cicd-webapp:latest"}
AWS_REGION=${2:-"us-east-1"}
APP_DIR="/opt/app"
LOG_FILE="/var/log/app-deploy.log"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "This script must be run as root"
        exit 1
    fi
}

# Function to setup Docker
setup_docker() {
    log "Setting up Docker..."
    systemctl start docker
    systemctl enable docker
}

# Function to pull and run Docker image
deploy_app() {
    log "Deploying application with image: $DOCKER_IMAGE"

    # Stop and remove existing container
    if docker ps -a --format 'table {{.Names}}' | grep -q "^cicd-app$"; then
        log "Stopping existing container..."
        docker stop cicd-app || true
        docker rm cicd-app || true
    fi

    # Pull latest image
    log "Pulling Docker image..."
    docker pull "$DOCKER_IMAGE"

    # Run new container
    log "Starting new container..."
    docker run -d \
        --name cicd-app \
        -p 3000:3000 \
        --restart unless-stopped \
        -e NODE_ENV=production \
        -e AWS_REGION="$AWS_REGION" \
        --log-driver awslogs \
        --log-opt awslogs-group=/aws/docker/cicd-app \
        --log-opt awslogs-region="$AWS_REGION" \
        --log-opt awslogs-stream-prefix=cicd-app \
        "$DOCKER_IMAGE"

    log "Container started successfully"
}

# Function to setup CloudWatch Logs
setup_cloudwatch_logs() {
    log "Setting up CloudWatch Logs..."

    # Create CloudWatch log group
    aws logs create-log-group --log-group-name /aws/docker/cicd-app --region "$AWS_REGION" || true

    # Set retention policy (30 days)
    aws logs put-retention-policy --log-group-name /aws/docker/cicd-app --retention-in-days 30 --region "$AWS_REGION" || true
}

# Function to install and configure CloudWatch agent
setup_cloudwatch_agent() {
    log "Setting up CloudWatch Agent..."

    # Create CloudWatch agent config
    mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "append_dimensions": {
            "InstanceId": "${aws:InstanceId}"
        },
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/app-deploy.log",
                        "log_group_name": "/aws/ec2/cicd-app",
                        "log_stream_name": "deployment.log"
                    }
                ]
            }
        }
    }
}
EOF

    # Start CloudWatch agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
}

# Function to health check
health_check() {
    log "Performing health check..."

    # Wait for container to start
    sleep 10

    # Check if container is running
    if docker ps --format 'table {{.Names}}' | grep -q "^cicd-app$"; then
        log "✅ Container is running"

        # Check health endpoint
        if curl -f http://localhost:3000/health > /dev/null 2>&1; then
            log "✅ Health check passed"
            return 0
        else
            log "❌ Health check failed"
            return 1
        fi
    else
        log "❌ Container is not running"
        return 1
    fi
}

# Main execution
main() {
    log "Starting deployment process..."

    check_root
    setup_docker
    setup_cloudwatch_logs
    deploy_app
    setup_cloudwatch_agent

    if health_check; then
        log "✅ Deployment completed successfully!"

        # Send notification (optional)
        if command -v aws >/dev/null 2>&1; then
            aws sns publish \
                --topic-arn arn:aws:sns:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):cicd-notifications \
                --subject "✅ Deployment Successful" \
                --message "Application deployed successfully with image: $DOCKER_IMAGE" \
                --region "$AWS_REGION" || true
        fi

        exit 0
    else
        log "❌ Deployment failed!"

        # Send failure notification (optional)
        if command -v aws >/dev/null 2>&1; then
            aws sns publish \
                --topic-arn arn:aws:sns:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):cicd-notifications \
                --subject "❌ Deployment Failed" \
                --message "Deployment failed for image: $DOCKER_IMAGE" \
                --region "$AWS_REGION" || true
        fi

        exit 1
    fi
}

# Run main function
main "$@"