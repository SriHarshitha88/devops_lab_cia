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
        DEPLOY_CREDENTIALS = 'aws-ssh-credentials'
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
                sh "echo 'Build Number: ${BUILD_NUMBER}' > BUILD_INFO"
                sh 'echo "Git Commit: $(cat GIT_COMMIT)" >> BUILD_INFO'
                sh 'echo "Build Time: $(date)" >> BUILD_INFO'
            }
        }

        stage('Install Dependencies') {
            steps {
                script {
                    docker.image('node:18-alpine').inside {
                        sh '''
                            npm ci
                        '''
                    }
                }
            }
        }

        stage('Code Quality Check') {
            parallel {
                stage('Lint') {
                    steps {
                        script {
                            docker.image('node:18-alpine').inside {
                                sh '''
                                    npm install -g eslint
                                    eslint . || true
                                '''
                            }
                        }
                    }
                }
                stage('Security Scan') {
                    steps {
                        script {
                            docker.image('node:18-alpine').inside {
                                sh 'npm audit --audit-level high || true'
                            }
                        }
                    }
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    docker.image('node:18-alpine').inside {
                        sh '''
                            npm test
                        '''
                    }
                }
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
                    sshagent(["${DEPLOY_CREDENTIALS}"]) {
                        sh """
                            # Copy deployment script to remote
                            scp -o StrictHostKeyChecking=no deploy.sh ec2-user@${DEPLOY_HOST}:/tmp/

                            # Execute deployment on remote host
                            ssh -o StrictHostKeyChecking=no ec2-user@${DEPLOY_HOST} "
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
                            <li>Docker Image: ${DOCKER_IMAGE_NAME}</li>
                            <li>Deployed to: ${DEPLOY_HOST}:3000</li>
                        </ul>
                        <p>Application URL: http://${DEPLOY_HOST}:3000</p>
                    """,
                    to: "devops@example.com"
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
                        <p>The CI/CD pipeline failed.</p>
                        <ul>
                            <li>Build Number: ${BUILD_NUMBER}</li>
                            <li>Check console output for details</li>
                        </ul>
                    """,
                    to: "devops@example.com"
                )
            }
        }
    }
}