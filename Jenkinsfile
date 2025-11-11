pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        ECR_REGISTRY = '987626324970.dkr.ecr.ap-south-1.amazonaws.com'
        ECR_REPO_NAME = 'aws-cicd-webapp'
        IMAGE_TAG = "${BUILD_NUMBER}"
        AWS_CREDENTIALS_ID = 'aws-credentials'
        DOCKER_IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"
        DEPLOY_HOST = 'ec2-15-206-159-55.ap-south-1.compute.amazonaws.com'
        DEPLOY_CREDENTIALS = credentials('aws-ssh-credentials')
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    git branch: 'main',
                        url: 'https://github.com/SriHarshitha88/devops_lab_cia.git',
                        credentialsId: 'github-credentials'
                }
                sh 'git rev-parse HEAD > GIT_COMMIT'
                sh 'echo "Build Number: ${BUILD_NUMBER}" > BUILD_INFO'
                sh 'echo "Git Commit: $(cat GIT_COMMIT)" >> BUILD_INFO'
                sh 'echo "Build Time: $(date)" >> BUILD_INFO'
            }
        }

        stage('Setup Environment') {
            steps {
                sh '''
                    echo "Setting up environment..."
                    node --version
                    npm --version
                    docker --version
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Code Quality Check') {
            parallel {
                stage('Lint') {
                    steps {
                        sh 'npm install -g eslint'
                        sh 'eslint . || true' // Continue even if linting fails
                    }
                }
                stage('Security Scan') {
                    steps {
                        sh 'npm audit --audit-level high || true'
                    }
                }
            }
        }

        stage('Test') {
            steps {
                sh '''
                    # Create test file if not exists
                    if [ ! -f tests/api.test.js ]; then
                        mkdir -p tests
                        cat > tests/api.test.js << 'EOF'
const request = require('supertest');
const app = require('../server');

describe('API Endpoints', () => {
  test('GET /api should return welcome message', async () => {
    const response = await request(app)
      .get('/api')
      .expect(200);

    expect(response.body.message).toContain('Welcome');
  });

  test('GET /health should return OK status', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body.status).toBe('OK');
  });
});
EOF
                    fi
                    npm test
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                        echo "Building Docker image: ${DOCKER_IMAGE_NAME}"
                        docker build -t ${DOCKER_IMAGE_NAME} .
                        echo "Tagging image as latest"
                        docker tag ${DOCKER_IMAGE_NAME} ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest
                    """
                }
            }
        }

        stage('Push to ECR') {
            steps {
                script {
                    withAWS(credentials: "${AWS_CREDENTIALS_ID}", region: "${AWS_REGION}") {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            docker push ${DOCKER_IMAGE_NAME}
                            docker push ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest

                            # Store image info
                            echo "${DOCKER_IMAGE_NAME}" > IMAGE_INFO
                            echo "${ECR_REGISTRY}/${ECR_REPO_NAME}:latest" >> IMAGE_INFO
                        """
                    }
                }
            }
        }

        stage('Deploy to AWS') {
            steps {
                script {
                    sshagent(["${DEPLOY_CREDENTIALS_ID}"]) {
                        sh """
                            # Copy deployment script to remote
                            scp -o StrictHostKeyChecking=no deploy.sh ${DEPLOY_HOST}:/tmp/

                            # Execute deployment on remote host
                            ssh -o StrictHostKeyChecking=no ${DEPLOY_HOST} "
                                chmod +x /tmp/deploy.sh
                                sudo /tmp/deploy.sh '${DOCKER_IMAGE_NAME}' '${AWS_REGION}'
                            "
                        """
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    sh """
                        echo "Waiting for application to be ready..."
                        sleep 30

                        # Health check
                        for i in {1..10}; do
                            if curl -f http://${DEPLOY_HOST}:3000/health; then
                                echo "Health check passed!"
                                break
                            else
                                echo "Health check attempt \$i failed, retrying..."
                                sleep 10
                            fi
                        done
                    """
                }
            }
        }
    }

    post {
        always {
            script {
                // Archive artifacts
                archiveArtifacts artifacts: 'BUILD_INFO,GIT_COMMIT,IMAGE_INFO', allowEmptyArchive: true

                // Clean up workspace
                sh 'docker system prune -f || true'
                cleanWs()
            }
        }

        success {
            script {
                // Send success notification
                emailext (
                    subject: "✅ SUCCESS: ${JOB_NAME} - Build #${BUILD_NUMBER}",
                    body: """
                        <h2>Build Successful!</h2>
                        <p>The CI/CD pipeline completed successfully.</p>
                        <ul>
                            <li>Build Number: ${BUILD_NUMBER}</li>
                            <li>Git Commit: ${env.GIT_COMMIT?.take(8)}</li>
                            <li>Docker Image: ${DOCKER_IMAGE_NAME}</li>
                            <li>Deployed to: ${DEPLOY_HOST}:3000</li>
                        </ul>
                        <p>Application URL: http://${DEPLOY_HOST}:3000</p>
                    """,
                    to: "${env.CHANGE_AUTHOR_EMAIL ?: 'devops@example.com'}"
                )
            }
        }

        failure {
            script {
                // Send failure notification
                emailext (
                    subject: "❌ FAILED: ${JOB_NAME} - Build #${BUILD_NUMBER}",
                    body: """
                        <h2>Build Failed!</h2>
                        <p>The CI/CD pipeline failed at stage ${currentBuild.currentResult}.</p>
                        <ul>
                            <li>Build Number: ${BUILD_NUMBER}</li>
                            <li>Failed Stage: ${currentBuild.currentResult}</li>
                            <li>Check console output for details</li>
                        </ul>
                    """,
                    to: "${env.CHANGE_AUTHOR_EMAIL ?: 'devops@example.com'}"
                )
            }
        }
    }
}