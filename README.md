# AWS CI/CD Pipeline Project

This project demonstrates a complete CI/CD pipeline for automated deployment of a Node.js web application on AWS using Jenkins, Docker, and GitHub.

## 🏗️ Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GitHub    │────▶│   Jenkins   │────▶│  AWS ECR    │────▶│  AWS EC2    │
│ Repository  │     │   Pipeline  │     │  Registry   │     │   Instance  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                            │                     │                     │
                            ▼                     ▼                     ▼
                       ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
                       │ Unit Tests  │     │ Docker     │     │ CloudWatch  │
                       │ & Quality   │     │ Build      │     │ Monitoring  │
                       └─────────────┘     └─────────────┘     └─────────────┘
```

## 📋 Prerequisites

### What You Need to Set Up:

#### 1. **AWS Account**
- Create an AWS account if you don't have one
- Configure AWS CLI with your credentials:
  ```bash
  aws configure
  ```

#### 2. **AWS CLI and Tools**
- Install AWS CLI v2
- Install jq (JSON processor)
- Install Git

#### 3. **Jenkins Server**
- Set up Jenkins server (can be on EC2 or on-premises)
- Required Jenkins plugins:
  - AWS Steps Plugin
  - Docker Pipeline Plugin
  - GitHub Integration Plugin
  - Email Extension Plugin

#### 4. **GitHub Setup**
- Fork this repository to your GitHub account
- Set up GitHub Personal Access Token with repo permissions
- Add webhook to Jenkins (Jenkins URL + `/github-webhook/`)

## 🚀 Setup Instructions

### Step 1: Set Up AWS Infrastructure

```bash
# Make the setup script executable
chmod +x aws/setup-infrastructure.sh

# Run the infrastructure setup
./aws/setup-infrastructure.sh us-east-1
```

This will create:
- ECR repository for Docker images
- IAM role for EC2 with necessary permissions
- Security group with required ports (22, 80, 3000)
- EC2 instance with Docker pre-installed

### Step 2: Configure Jenkins

1. **Add Credentials in Jenkins**:
   - AWS credentials: `aws-credentials`
   - ECR registry URL: `aws-ecr-registry-url`
   - SSH credentials for EC2: `aws-ssh-credentials`
   - GitHub credentials: `github-credentials`

2. **Create Jenkins Pipeline Job**:
   - New Item → Pipeline
   - Select "Pipeline script from SCM"
   - SCM: Git
   - Repository URL: `https://github.com/SriHarshitha88/devops_lab_cia.git`
   - Credentials: Select GitHub credentials
   - Script Path: `Jenkinsfile`

### Step 3: Update Jenkinsfile Configuration

Update the following environment variables in `Jenkinsfile`:
- `AWS_REGION`: Your AWS region
- `ECR_REGISTRY`: Your ECR registry URL
- `DEPLOY_HOST`: Your EC2 instance public IP

### Step 4: Configure Webhook

1. Go to your GitHub repository settings
2. Webhooks → Add webhook
3. Payload URL: `http://your-jenkins-server:8080/github-webhook/`
4. Content type: `application/json`
5. Events: Select "Just the `push` event"

## 📦 Deployment Process

The pipeline automatically triggers on every push to the main branch:

1. **Checkout**: Pulls latest code from GitHub
2. **Setup**: Prepares build environment
3. **Install Dependencies**: Installs npm packages
4. **Quality Checks**: Runs linting and security scans
5. **Test**: Executes unit tests
6. **Build Docker**: Creates container image
7. **Push to ECR**: Uploads image to AWS registry
8. **Deploy**: Deploys to EC2 instance
9. **Health Check**: Verifies application is running

## 🔧 Manual Commands

### Build and Run Locally
```bash
# Install dependencies
npm install

# Run tests
npm test

# Build Docker image
docker build -t aws-cicd-webapp .

# Run container
docker run -p 3000:3000 aws-cicd-webapp
```

### Deploy Manually
```bash
# Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin your-ecr-registry-url
docker tag aws-cicd-webapp:latest your-ecr-registry-url/aws-cicd-webapp:latest
docker push your-ecr-registry-url/aws-cicd-webapp:latest

# SSH into EC2
ssh -i cicd-key-pair.pem ec2-user@your-ec2-ip

# Deploy on EC2
sudo ./deploy.sh your-ecr-registry-url/aws-cicd-webapp:latest us-east-1
```

## 📊 Monitoring

### CloudWatch Metrics
- CPU Utilization
- Memory Usage
- Network I/O
- Disk Usage

### CloudWatch Logs
- Application logs: `/aws/docker/cicd-app`
- Deployment logs: `/aws/ec2/cicd-app`

### Health Checks
- Application health endpoint: `http://<ec2-ip>:3000/health`

## 🧪 Testing

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Run linting
npm run lint
```

## 📸 Submission Screenshots

Here's what you need to capture for submission:

### 1. Jenkins Pipeline Stages
- View in Jenkins UI after pipeline runs
- Show all stages (Checkout, Test, Build, Deploy, etc.)

### 2. Docker Image in ECR
- AWS Console → ECR → Repository
- Show image tags and push details

### 3. Application Running on Cloud
- Open `http://<ec2-ip>:3000` in browser
- Capture the application interface

### 4. Jenkinsfile
- Show the complete pipeline configuration
- Display in IDE or GitHub

### 5. CloudWatch Dashboard
- Show metrics and logs
- Display monitoring data

## 🔐 Security Considerations

- Never commit AWS credentials to version control
- Use IAM roles instead of access keys when possible
- Rotate keys regularly
- Enable VPC flow logs
- Use security groups to restrict access

## 🛠️ Troubleshooting

### Common Issues:

1. **Docker build fails**:
   - Check Dockerfile syntax
   - Verify .dockerignore is correct

2. **ECR push fails**:
   - Verify AWS credentials
   - Check ECR repository permissions
   - Ensure Docker login succeeded

3. **Deployment fails**:
   - Check SSH connectivity to EC2
   - Verify Docker is running on EC2
   - Check deploy.sh permissions

4. **Health check fails**:
   - Verify application is listening on port 3000
   - Check security group settings
   - Review application logs

## 📝 Configuration Files

- `Jenkinsfile`: CI/CD pipeline definition
- `Dockerfile`: Container image specification
- `deploy.sh`: Remote deployment script
- `aws/setup-infrastructure.sh`: AWS resource creation
- `package.json`: Node.js dependencies and scripts

## 📞 Support

For issues:
1. Check Jenkins console output
2. Review CloudWatch logs
3. Verify AWS resource configuration
4. Test locally first

---

**Happy Deploying! 🎉**