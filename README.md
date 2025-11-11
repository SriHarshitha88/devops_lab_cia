# AWS CI/CD Pipeline Project

This project demonstrates a complete CI/CD pipeline for automated deployment of a Node.js web application on AWS using Jenkins, Docker, and GitHub.

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DEVELOPER WORKFLOW                                    │
└─────────────────────────┬───────────────────────────────────────────────────┘
                          │
                          │ Git Push (code changes)
                          ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              GITHUB                                            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
│  │   server.js │    │package.json │    │ Dockerfile  │    │Jenkinsfile  │   │
│  │             │    │             │    │             │    │             │   │
│  │             │    │             │    │             │    │             │   │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘   │
│           │                  │                  │                  │          │
│           └──────────────────┴──────────────────┴──────────────────┘          │
│                           │                                                     │
│                           │ Webhook Trigger                                     │
└───────────────────────────┼─────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            JENKINS SERVER                                       │
│                                                                                 │
│  ┌────────────────────── CI/CD PIPELINE STAGES ──────────────────────┐         │
│  │                                                                  │         │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │         │
│  │  │ Checkout │→ │Build/Test│→ │Docker    │→ │Push ECR  │         │         │
│  │  │          │  │          │  │Build     │  │          │         │         │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘         │         │
│  │                                                            │   │         │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐               ▼   │         │
│  │  │Deploy    │→ │Health    │→ │Notify    │          ┌─────────┐  │         │
│  │  │to EC2    │  │Check     │  │Success   │          │Artifacts│  │         │
│  │  │          │  │          │  │          │          │Archive  │  │         │
│  │  └──────────┘  └──────────┘  └──────────┘          └─────────┘  │         │
│  └──────────────────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────────────┘
                            │
                            │ SSH Deployment
                            ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          AWS CLOUD INFRASTRUCTURE                                │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐           │
│  │                         AMAZON EC2                              │           │
│  │  ┌───────────────────────────────────────────────────────┐    │           │
│  │  │              Docker Container                           │    │           │
│  │  │  ┌─────────────────────────────────────────────┐      │    │           │
│  │  │  │         Node.js Web Application              │      │    │           │
│  │  │  │  ┌─────────┐  ┌─────────┐  ┌─────────────┐  │      │    │           │
│  │  │  │  │ Server  │  │ Express │  │ Health Check│  │      │    │           │
│  │  │  │    .js   │  │         │  │  Endpoint   │  │      │    │           │
│  │  │  └─────────┘  └─────────┘  └─────────────┘  │      │    │           │
│  │  └───────────────────────────────────────────────────────┘    │           │
│  │                              │ Port 3000                     │           │
│  └──────────────────────────────┼───────────────────────────────┘           │
│                                 │                                      │
│  ┌──────────────────────────────┼───────────────────────────────┐           │
│  │         AWS CLOUD SERVICES    │           MONITORING           │           │
│  │                              │                              │           │
│  │  ┌─────────────┐             │  ┌─────────────┐              │           │
│  │  │     ECR     │◄────────────┘  │CloudWatch   │              │           │
│  │  │(Container   │   Docker      │             │              │           │
│  │  │ Registry)   │   Images     │ • Metrics   │              │           │
│  │  │             │              │ • Logs      │              │           │
│  │  └─────────────┘              │ • Alarms    │              │           │
│  │                                └─────────────┘              │           │
│  └───────────────────────────────────────────────────────────────┘           │
│                                                                                 │
│                                 │                                              │
│                                 ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────┐           │
│  │                      INTERNET ACCESS                             │           │
│  │                                                                 │           │
│  │  https://ec2-15-206-159-55.ap-south-1.compute.amazonaws.com    │           │
│  │      │                                                         │           │
│  │      ├─ / (Application UI)                                     │           │
│  │      ├─ /api (REST API)                                        │           │
│  │      ├─ /api/users (Users Endpoint)                             │           │
│  │      └─ /health (Health Check)                                 │           │
│  └─────────────────────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## 📋 Expected Outcomes

### 1. **Source Code Management** ✅
- Use Git and GitHub for version control
- Clear branching strategy (main branch)
- Webhook integration triggers Jenkins automatically on code commits

### 2. **Continuous Integration (CI)** ✅
- Jenkins configured to:
  - Pull latest code from repository
  - Build the project using npm
  - Run unit tests
  - Create Docker image

### 3. **Containerization** ✅
- Dockerfile created to containerize the application
- Docker image built and tagged during CI process
- Multi-stage build for optimization

### 4. **Container Registry** ✅
- Push to AWS Elastic Container Registry (ECR)
- Image versioning with build numbers
- Latest tag always updated

### 5. **Continuous Deployment (CD)** ✅
- Deploy containerized application to AWS EC2
- Automatic deployment after ECR push
- Zero-downtime deployment strategy

### 6. **Monitoring & Logging** ✅
- CloudWatch integration for:
  - Application metrics
  - Container logs
  - Health check endpoints
  - Email notifications for pipeline status

## 🚀 Quick Start

### Prerequisites
- AWS account with IAM permissions
- Jenkins server with required plugins
- Docker installed
- GitHub repository with webhook

### Installation Steps

1. **Clone the repository**
```bash
git clone https://github.com/SriHarshitha88/devops_lab_cia.git
cd devops_lab_cia
```

2. **Set up Jenkins pipeline**
- Create new pipeline job
- Configure GitHub webhook
- Add credentials (GitHub, AWS, SSH)

3. **Configure AWS infrastructure**
- Create ECR repository
- Launch EC2 instance with Docker
- Set up security groups

4. **Run the pipeline**
- Push changes to GitHub
- Pipeline triggers automatically
- Application deployed to EC2

## 📦 Technology Stack

- **Version Control**: GitHub
- **CI/CD**: Jenkins
- **Containerization**: Docker
- **Cloud Platform**: AWS
  - EC2 (Compute)
  - ECR (Container Registry)
  - CloudWatch (Monitoring)
- **Application**: Node.js + Express

## 📸 Submission Screenshots

For your assignment submission, you need screenshots of:

1. **Jenkins Pipeline Stages**
   - All stages executing successfully
   - Console output showing completion

2. **Docker Image in ECR**
   - Navigate to AWS Console → ECR
   - Show `aws-cicd-webapp` repository
   - Display image tags and push details

3. **Application Running on Cloud**
   - Visit: http://ec2-15-206-159-55.ap-south-1.compute.amazonaws.com:3000
   - Screenshot the application interface
   - Show health check endpoint

4. **Jenkinsfile**
   - View in GitHub repository
   - Shows complete pipeline configuration

## 🔧 Configuration Files

- `Jenkinsfile`: CI/CD pipeline definition
- `Dockerfile`: Container image specification
- `package.json`: Node.js dependencies and scripts
- `server.js`: Main application file
- `tests/`: Unit test files
- `deploy.sh`: Deployment script for EC2

## 🌐 Application Endpoints

Once deployed, the application is available at:

- **Main Application**: http://ec2-15-206-159-55.ap-south-1.compute.amazonaws.com:3000
- **Health Check**: http://ec2-15-206-159-55.ap-south-1.compute.amazonaws.com:3000/health
- **API Endpoint**: http://ec2-15-206-159-55.ap-south-1.compute.amazonaws.com:3000/api
- **Users API**: http://ec2-15-206-159-55.ap-south-1.compute.amazonaws.com:3000/api/users

## 📊 Pipeline Flow Summary

1. **Developer** pushes code to **GitHub**
2. **Webhook** triggers **Jenkins** pipeline
3. **Jenkins**:
   - Checks out code
   - Runs tests
   - Builds Docker image
   - Pushes to **ECR**
4. **EC2** pulls image from **ECR**
5. **Docker** runs container on **EC2**
6. **CloudWatch** monitors application
7. **User** accesses application via public URL

---

**Built with ❤️ for DevOps demonstration**