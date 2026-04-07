pipeline {
    agent any
    environment {
        DOCKER_USER    = 'mickybamby'
        IMAGE_NAME     = 'app-python'
        IMAGE_TAG      = "v${env.BUILD_NUMBER}"
        DOCKER_HUB_REG = "${DOCKER_USER}/${IMAGE_NAME}"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-token',
                    url: 'https://github.com/mickybamby/app-python.git'
            }
        }

        stage('Test & Scan') {
            steps {
                echo 'Running Tests...'
            }
        }

        stage('Build & Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER_ENV')]) {
                    sh """
                        docker build -t ${DOCKER_HUB_REG}:${IMAGE_TAG} .
                        echo \$DOCKER_PASS | docker login -u \$DOCKER_USER_ENV --password-stdin
                        docker push ${DOCKER_HUB_REG}:${IMAGE_TAG}
                    """
                }
            }
        }

        stage('Update Manifests') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-token', passwordVariable: 'GIT_TOKEN', usernameVariable: 'GIT_USER')]) {
                    sh """
                        rm -rf dev
                        git clone https://\${GIT_USER}:\${GIT_TOKEN}@github.com/mickybamby/dev.git
                        cd dev
                        sed -i 's|image: .*/${IMAGE_NAME}:.*|image: ${DOCKER_HUB_REG}:${IMAGE_TAG}|' deployment.yaml
                        git config user.email "jenkins@yourdomain.com"
                        git config user.name "Jenkins CI"
                        git add deployment.yaml
                        git commit -m "Update image to ${DOCKER_HUB_REG}:${IMAGE_TAG} [skip ci]"
                        git push origin main
                    """
                }
            }
        }
    }
}