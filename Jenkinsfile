pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo "Building..."
                // e.g., sh 'python setup.py build' 
            }
        }

        stage('Test') {
            steps {
                echo 'Testing...'
                // e.g., sh 'pytest tests/'
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying...'
                // e.g., sh './deploy.sh'
            }
        }
    }
}
