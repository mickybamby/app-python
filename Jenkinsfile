pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = 'dockerhub-credentials'
        DOCKERHUB_USERNAME = credentials('dockerhub-username')
        IMAGE_NAME = 'app-python'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/mickybamby/app-python.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    try {
                        dockerImage = docker.build("${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${env.BUILD_NUMBER}")
                    } catch (e) {
                        error "Docker build failed: ${e}"
                    }
                }
            }
        }

        stage('Test Docker Image') {
            steps {
                script {
                    dockerImage.inside {
                        sh './run-tests.sh'
                    }
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', DOCKERHUB_CREDENTIALS) {
                        dockerImage.push()
                        dockerImage.push('latest')
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Docker image successfully built, tested, and pushed to Docker Hub!"
        }
        failure {
            echo "Pipeline failed. Check the logs for errors."
        }
        always {
            script {
                sh "docker rmi ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${env.BUILD_NUMBER} || true"
            }
        }
    }
}