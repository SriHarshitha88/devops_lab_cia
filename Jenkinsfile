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
                git branch: 'main',
                    url: 'https://github.com/SriHarshitha88/devops_lab_cia.git',
                    credentialsId: 'github-credentials'
                sh 'git rev-parse HEAD > GIT_COMMIT'
                sh "echo 'Build Number: ${BUILD_NUMBER}' > BUILD_INFO"
                sh 'echo "Git Commit: $(cat GIT_COMMIT)" >> BUILD_INFO'
                sh 'echo "Build Time: $(date)" >> BUILD_INFO'
            }
        }

        stage('Deploy to AWS EC2') {
            steps {
                script {
                    sshagent(["${DEPLOY_CREDENTIALS}"]) {
                        sh """
                            # Create build directory on EC2
                            ssh -o StrictHostKeyChecking=no ec2-user@${DEPLOY_HOST} '
                                rm -rf /tmp/cicd-build
                                mkdir -p /tmp/cicd-build
                            '

                            # Copy all files to EC2
                            scp -o StrictHostKeyChecking=no -r * ec2-user@${DEPLOY_HOST}:/tmp/cicd-build/

                            # Build and deploy on EC2
                            ssh -o StrictHostKeyChecking=no ec2-user@${DEPLOY_HOST} "
                                cd /tmp/cicd-build

                                echo '📦 Installing dependencies and running tests...'
                                npm ci
                                npm test

                                echo '🔨 Building Docker image...'
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                docker build -t ${DOCKER_IMAGE_NAME} .
                                docker tag ${DOCKER_IMAGE_NAME} ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest

                                echo '📤 Pushing to ECR...'
                                docker push ${DOCKER_IMAGE_NAME}
                                docker push ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest

                                echo '🚀 Deploying application...'
                                docker stop cicd-app || true
                                docker rm cicd-app || true
                                docker run -d \\
                                    --name cicd-app \\
                                    -p 3000:3000 \\
                                    --restart unless-stopped \\
                                    -e NODE_ENV=production \\
                                    ${DOCKER_IMAGE_NAME}

                                echo '✅ Deployment completed successfully!'
                                docker ps | grep cicd-app
                            "

                            # Store deployment info
                            echo "${DOCKER_IMAGE_NAME}" > IMAGE_INFO
                            echo "${ECR_REGISTRY}/${ECR_REPO_NAME}:latest" >> IMAGE_INFO
                        """
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                sh """
                    echo '⏳ Waiting for application to start...'
                    sleep 30

                    # Check if application is responding
                    max_attempts=10
                    attempt=1

                    while [ \$attempt -le \$max_attempts ]; do
                        echo "🔍 Health check attempt \$attempt..."
                        if curl -f http://${DEPLOY_HOST}:3000/health; then
                            echo '✅ Health check passed!'
                            echo ''
                            echo '🎉 APPLICATION IS LIVE!'
                            echo "📍 URL: http://${DEPLOY_HOST}:3000"
                            break
                        else
                            echo "❌ Health check failed, retrying in 10 seconds..."
                            sleep 10
                            attempt=\$((attempt + 1))
                        fi
                    done

                    if [ \$attempt -gt \$max_attempts ]; then
                        echo '❌ Health check failed after all attempts'
                        exit 1
                    fi
                """
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'BUILD_INFO,GIT_COMMIT,IMAGE_INFO', allowEmptyArchive: true
            cleanWs()
        }

        success {
            echo """
                ✅✅✅ PIPELINE SUCCESSFUL! ✅✅✅

                🚀🚀🚀 APPLICATION DEPLOYED SUCCESSFULLY! 🚀🚀🚀

                📍 Main URL: http://${DEPLOY_HOST}:3000
                🔍 Health: http://${DEPLOY_HOST}:3000/health
                📊 API: http://${DEPLOY_HOST}:3000/api
                👥 Users API: http://${DEPLOY_HOST}:3000/api/users

                📸 SCREENSHOTS NEEDED FOR SUBMISSION:
                1. Jenkins pipeline stages (this page)
                2. ECR repository: https://console.aws.amazon.com/ecr/
                3. Running app: http://${DEPLOY_HOST}:3000
                4. Jenkinsfile: https://github.com/SriHarshitha88/devops_lab_cia/blob/main/Jenkinsfile
            """
        }

        failure {
            echo """
                ❌❌❌ PIPELINE FAILED! ❌❌❌

                Troubleshooting tips:
                1. Check SSH credentials in Jenkins
                2. Verify EC2 instance is running
                3. Ensure AWS credentials are correct
                4. Check if Docker is running on EC2
            """
        }
    }
}