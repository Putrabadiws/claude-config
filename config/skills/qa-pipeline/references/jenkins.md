# Jenkins Pipeline Patterns

## Table of Contents

- [Pattern 1: Per-Service Pipeline (runs on every PR)](#pattern-1-per-service-pipeline-runs-on-every-pr)
- [Pattern 2: E2E Repo Pipeline (standalone, triggered by release)](#pattern-2-e2e-repo-pipeline-standalone-triggered-by-release)
- [Nightly Full E2E Schedule](#nightly-full-e2e-schedule)
- [Parallel Sharding](#parallel-sharding)
- [Allure Post Block](#allure-post-block)
- [Caching (Maven Dependencies)](#caching-maven-dependencies)
- [Security Scan Stage](#security-scan-stage)
- [Quarantine Stage](#quarantine-stage)

## Pattern 1: Per-Service Pipeline (runs on every PR)

```groovy
// Jenkinsfile — standard service pipeline
pipeline {
    agent any
    tools {
        jdk 'jdk-17'
        maven 'maven-3.8'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Unit Tests') {
            steps {
                sh './mvnw clean test -B'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                    jacoco(execPattern: '**/target/jacoco.exec')
                }
            }
        }

        stage('Integration Tests') {
            steps {
                sh './mvnw verify -Pintegration-test -B'
            }
        }

        stage('OWASP Dependency Check') {
            steps {
                sh './mvnw org.owasp:dependency-check-maven:check'
            }
            post {
                always {
                    dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh './mvnw sonar:sonar'
                }
            }
        }

        stage('Docker Build & Push') {
            when { branch 'release' }
            steps {
                script {
                    def tag = "1.0.0-${env.BRANCH_NAME}-${new Date().format('yyyyMMddHHmm')}-${env.BUILD_NUMBER}"
                    sh "docker build -t ${REGISTRY}/${GROUP}/${APP_NAME}:${tag} ."
                    sh "docker push ${REGISTRY}/${GROUP}/${APP_NAME}:${tag}"
                }
            }
        }

        stage('Deploy to Dev') {
            when { branch 'release' }
            steps {
                sh '''
                    kubectl --context=${KUBE_CONTEXT} -n ${DEV_NAMESPACE} \
                        set image deployment/${APP_NAME} ${APP_NAME}=${IMAGE}:${TAG}
                '''
            }
        }
    }

    post {
        always {
            // Chat notification
            googlechatnotification url: "${CHAT_WEBHOOK}",
                message: "Build ${currentBuild.result}: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        }
    }
}
```

## Pattern 2: E2E Repo Pipeline (standalone, triggered by release)

```groovy
// e2e/<suite>/Jenkinsfile
pipeline {
    agent any
    parameters {
        string(name: 'BASE_URL', defaultValue: 'https://staging.example.com')
        string(name: 'STACK_VERSION', defaultValue: 'unknown')
    }

    stages {
        stage('Setup') {
            steps {
                sh '''
                    cd e2e/<suite>
                    <workspace>/py/venv/bin/pip install -r requirements.txt
                    <workspace>/py/venv/bin/python -m playwright install chromium
                '''
            }
        }

        stage('API Tests') {
            steps {
                sh '''
                    cd e2e/<suite>
                    <workspace>/py/venv/bin/pytest tests/api/ \
                        --ignore=quarantine/ \
                        -v --alluredir=allure-results \
                        --base-url=${BASE_URL}
                '''
            }
        }

        stage('Journey Tests') {
            steps {
                sh '''
                    cd e2e/<suite>
                    <workspace>/py/venv/bin/pytest tests/journeys/ \
                        --ignore=quarantine/ \
                        -v --alluredir=allure-results \
                        --base-url=${BASE_URL}
                '''
            }
        }
    }

    post {
        always {
            allure includeProperties: false, results: [[path: 'allure-results']]
            archiveArtifacts artifacts: 'allure-results/**', allowEmptyArchive: true
        }
    }
}
```

## Nightly Full E2E Schedule

```groovy
pipeline {
    triggers { cron('H 2 * * *') }  // 2 AM daily
    stages {
        stage('Nightly E2E') {
            steps {
                sh '''
                    cd e2e/<suite>
                    <workspace>/py/venv/bin/pytest --ignore=quarantine/ \
                        -v --alluredir=allure-results \
                        --base-url=https://staging.example.com
                '''
            }
        }
    }
}
```

## Parallel Sharding

```groovy
// Jenkins parallel sharding
stage('E2E Sharded') {
    parallel {
        stage('Shard 1') { steps { sh 'pytest --shard-id=0 --num-shards=4 tests/' } }
        stage('Shard 2') { steps { sh 'pytest --shard-id=1 --num-shards=4 tests/' } }
        stage('Shard 3') { steps { sh 'pytest --shard-id=2 --num-shards=4 tests/' } }
        stage('Shard 4') { steps { sh 'pytest --shard-id=3 --num-shards=4 tests/' } }
    }
}
```

## Allure Post Block

```groovy
post {
    always {
        allure includeProperties: false,
            jdk: '',
            results: [[path: 'allure-results']]
    }
}
```

## Caching (Maven Dependencies)

```groovy
// Cache Maven dependencies
options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
}
environment {
    MAVEN_OPTS = '-Dmaven.repo.local=$WORKSPACE/.m2/repository'
}
```

## Security Scan Stage

```groovy
// Jenkinsfile — add to per-service pipeline
stage('Security Scan') {
    parallel {
        stage('Dependency Audit') {
            steps {
                sh './mvnw org.owasp:dependency-check-maven:check'
            }
            post {
                always {
                    dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                }
            }
        }
        stage('Container Scan') {
            steps {
                sh "trivy image --exit-code 0 --severity HIGH,CRITICAL ${REGISTRY}/${GROUP}/${APP_NAME}:${TAG}"
            }
        }
    }
}
```

## Quarantine Stage

Flaky tests live in `quarantine/` and are excluded from main runs via `--ignore=quarantine/`. Run them separately to track stability:

```groovy
stage('Quarantine (Informational)') {
    steps {
        sh '''
            cd e2e/<suite>
            <workspace>/py/venv/bin/pytest quarantine/ \
                -v --alluredir=allure-results-quarantine || true
        '''
    }
}
```
