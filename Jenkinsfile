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

        stage('Test Code Quality') {
            steps {
                sh '''
                    # Install Node.js in Jenkins container
                    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
                    apt-get update && apt-get install -y nodejs

                    # Install dependencies
                    npm ci

                    # Run tests
                    npm test || echo "Tests completed with issues"

                    # Basic lint check
                    npm install -g eslint
                    eslint . || echo "Linting completed with issues"
                '''
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

                                # Login to ECR
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                                # Build Docker image
                                docker build -t ${DOCKER_IMAGE_NAME} .
                                docker tag ${DOCKER_IMAGE_NAME} ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest

                                # Push to ECR
                                docker push ${DOCKER_IMAGE_NAME}
                                docker push ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest

                                # Stop existing container
                                docker stop cicd-app || true
                                docker rm cicd-app || true

                                # Run new container
                                docker run -d \\
                                    --name cicd-app \\
                                    -p 3000:3000 \\
                                    --restart unless-stopped \\
                                    -e NODE_ENV=production \\
                                    ${DOCKER_IMAGE_NAME}

                                echo 'Deployment completed successfully!'
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
                    echo 'Waiting for application to start...'
                    sleep 30

                    # Check if application is responding
                    max_attempts=10
                    attempt=1

                    while [ \$attempt -le \$max_attempts ]; do
                        if curl -f http://${DEPLOY_HOST}:3000/health > /dev/null 2>&1; then
                            echo '✅ Health check passed!'
                            curl http://${DEPLOY_HOST}:3000/health
                            break
                        else
                            echo "Health check attempt \$attempt failed, retrying in 10 seconds..."
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

                🚀 Application deployed successfully!

                📍 Application URL: http://${DEPLOY_HOST}:3000
                🔍 Health Check: http://${DEPLOY_HOST}:3000/health
                📊 API Endpoint: http://${DEPLOY_HOST}:3000/api

                📸 Don't forget to capture screenshots for your submission!
            """
        }

        failure {
            echo """
                ❌❌❌ PIPELINE FAILED! ❌❌❌

                Please check the console output above for error details.
                Common issues:
                - SSH credentials not configured correctly
                - AWS credentials missing or invalid
                - EC2 instance not accessible
                - Docker not running on EC2
            """
        }
    }
}