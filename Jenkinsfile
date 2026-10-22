
pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    parameters {
        choice(
            name: 'RELEASE_MODE',
            choices: ['NORMAL', 'FAULTY'],
            description: 'Select normal release or faulty release for rollback test'
        )
        booleanParam(
            name: 'DEPLOY_TO_K8S',
            defaultValue: true,
            description: 'Deploy to Kubernetes'
        )
    }

    environment {
        IMAGE_NAME = 'niharikarao15/transport-dashboard'
        DOCKER_EXE = 'C:\\Users\\Niharika\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin\\docker.exe'
        KUBECTL_EXE = 'C:\\Program Files\\Docker\\Docker\\resources\\bin\\kubectl.exe'
        KUBECONFIG = 'C:\\Users\\Niharika\\.kube\\config'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/niha1526/public-transport-monitoring-dashboard.git'
            }
        }

        stage('Parallel Validation') {
            parallel {
                stage('Validate Dashboard') {
                    steps {
                        powershell '''
                            $html = Get-Content index.html -Raw

                            foreach ($term in @(
                                "routeFilter",
                                "Passenger Advisories",
                                "disruptions",
                                "Moderate",
                                "High"
                            )) {
                                if ($html -notmatch [regex]::Escape($term)) {
                                    throw "Missing dashboard content: $term"
                                }
                            }

                            Write-Output "Dashboard validation passed"
                        '''
                    }
                }

                stage('Validate Required Files') {
                    steps {
                        powershell '''
                            foreach ($file in @(
                                "Dockerfile",
                                "Jenkinsfile",
                                "deployment.yaml",
                                "health.html"
                            )) {
                                if (!(Test-Path $file)) {
                                    throw "Missing file: $file"
                                }
                            }

                            Write-Output "Required files validated"
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                powershell '''
                    if (!(Test-Path $env:DOCKER_EXE)) {
                        throw "Docker executable not found: $env:DOCKER_EXE"
                    }

                    & $env:DOCKER_EXE build `
                        --build-arg "RELEASE_MODE=$env:RELEASE_MODE" `
                        -t "$env:IMAGE_NAME`:$env:BUILD_NUMBER" .

                    if ($LASTEXITCODE -ne 0) {
                        throw "Docker build failed"
                    }
                '''
            }
        }

        stage('Push Image to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    powershell '''
                        $env:DOCKERHUB_TOKEN |
                            & $env:DOCKER_EXE login `
                                -u $env:DOCKERHUB_USER --password-stdin

                        if ($LASTEXITCODE -ne 0) {
                            throw "Docker Hub login failed"
                        }

                        & $env:DOCKER_EXE push `
                            "$env:IMAGE_NAME`:$env:BUILD_NUMBER"

                        if ($LASTEXITCODE -ne 0) {
                            throw "Docker image push failed"
                        }

                        & $env:DOCKER_EXE logout
                    '''
                }
            }
        }

        stage('Archive Build Artifacts') {
            steps {
                archiveArtifacts(
                    artifacts: 'index.html,Dockerfile,health.html,deployment.yaml',
                    fingerprint: true
                )
            }
        }

        stage('Deploy and Verify') {
            when {
                expression { params.DEPLOY_TO_K8S }
            }

            steps {
                powershell '''
                    if (!(Test-Path $env:KUBECTL_EXE)) {
                        throw "kubectl not found: $env:KUBECTL_EXE"
                    }

                    if (!(Test-Path $env:KUBECONFIG)) {
                        throw "Kubeconfig not found: $env:KUBECONFIG"
                    }

                    & $env:KUBECTL_EXE config current-context
                    if ($LASTEXITCODE -ne 0) {
                        throw "Kubernetes context unavailable"
                    }

                    & $env:KUBECTL_EXE get nodes
                    if ($LASTEXITCODE -ne 0) {
                        throw "Kubernetes cluster unavailable"
                    }

                    # Create the initial Deployment if it does not exist.
                    & $env:KUBECTL_EXE get deployment transport-dashboard 2>$null

                    if ($LASTEXITCODE -ne 0) {
                        & $env:KUBECTL_EXE apply -f deployment.yaml

                        if ($LASTEXITCODE -ne 0) {
                            throw "Initial Deployment creation failed"
                        }
                    }

                    # Update directly to the newly built application image.
                    & $env:KUBECTL_EXE set image `
                        deployment/transport-dashboard `
                        "transport-dashboard=$env:IMAGE_NAME`:$env:BUILD_NUMBER"

                    if ($LASTEXITCODE -ne 0) {
                        throw "Deployment image update failed"
                    }

                    # Wait for the new revision to become healthy.
                    & $env:KUBECTL_EXE rollout status `
                        deployment/transport-dashboard --timeout=90s

                    if ($LASTEXITCODE -ne 0) {
                        Write-Output "ROLLOUT FAILED - AUTOMATIC ROLLBACK STARTED"

                        & $env:KUBECTL_EXE rollout undo `
                            deployment/transport-dashboard

                        if ($LASTEXITCODE -ne 0) {
                            throw "Rollback command failed"
                        }

                        & $env:KUBECTL_EXE rollout status `
                            deployment/transport-dashboard --timeout=120s

                        if ($LASTEXITCODE -ne 0) {
                            throw "Previous release did not recover"
                        }

                        & $env:KUBECTL_EXE get pods -l app=transport-dashboard

                        throw "Faulty release rejected; previous revision restored"
                    }

                    & $env:KUBECTL_EXE get deployment transport-dashboard
                    & $env:KUBECTL_EXE get pods -l app=transport-dashboard
                    & $env:KUBECTL_EXE get service transport-dashboard-service

                    Write-Output "Deployment successful"
                '''
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Check the Console Output.'
        }
        always {
            echo 'Pipeline execution finished.'
        }
    }
}
