#!/usr/bin/env groovy

def getAccountId(String environment) {
    def account_info = [
        management  : ["account_id": "419929493928"],
        integration : ["account_id": "150648916438"],
        staging     : ["account_id": "186795391298"],
        qa          : ["account_id": "248771275994"],
        externaltest: ["account_id": "970278273631"],
        production  : ["account_id": "490818658393"],
        development : ["account_id": "618259438944"]
    ]
    account_info[environment].account_id
}

def awsEnv(environment) {
    """set +x
    SESSIONID=\$(date +"%s")
    AWS_CREDENTIALS=\$(aws sts assume-role --role-arn arn:aws:iam::${ getAccountId(environment) }:role/service/RoleJenkinsTerraformProvisioner --role-session-name \$SESSIONID --query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' --output text)
    export AWS_ACCESS_KEY_ID=\$(echo \$AWS_CREDENTIALS | awk '{print \$1}')
    export AWS_SECRET_ACCESS_KEY=\$(echo \$AWS_CREDENTIALS | awk '{print \$2}')
    export AWS_SESSION_TOKEN=\$(echo \$AWS_CREDENTIALS | awk '{print \$3}')
    export ENVIRONMENT="${environment}"
    set -x
    """
}

pipeline {

    agent {
        node {
            label 'performance'
            customWorkspace "${JENKINS_HOME}/workspace/${JOB_NAME}/${BUILD_NUMBER}"
        }
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['local', 'staging', 'qa'], description: 'Named test environment')
        string(name: 'LOCUST_HOST', defaultValue: '', description: 'Optional override for the Envoy target host')
        string(name: 'LOCUST_HOST_HEADER', defaultValue: '', description: 'Optional override for the HTTP Host header when using direct internal targets')
        string(name: 'users', defaultValue: '50', description: 'Number of concurrent Locust users')
        string(name: 'duration', defaultValue: '5m', description: 'Test run duration (e.g. 5m, 1h)')
        string(name: 'spawn_rate', defaultValue: '5', description: 'Users spawned per second')
        string(name: 'loss_threshold', defaultValue: '1.0', description: 'Max acceptable audit event loss %')
    }

    stages {

        stage('Test') {
            steps {
                script {
                    def envHosts = [
                        local: 'http://upstream:9090',
                        staging: 'https://envoy-audit.staging.tax.service.gov.uk',
                        qa: 'https://envoy-audit.qa.tax.service.gov.uk'
                    ]
                    def targetHost = params.LOCUST_HOST?.trim() ? params.LOCUST_HOST : envHosts[params.ENVIRONMENT]

                    sh """#!/bin/bash -e
                        NUMBER_OF_CORES=\$(nproc)

                        make test \\
                          ENVIRONMENT=${params.ENVIRONMENT} \\
                          LOCUST_HOST='${targetHost}' \\
                          LOCUST_HOST_HEADER='${params.LOCUST_HOST_HEADER}' \\
                          TEST_WORKERS=\${NUMBER_OF_CORES} \\
                          LOCUST_USERS=${params.users} \\
                          LOCUST_RUN_TIME=${params.duration} \\
                          LOCUST_SPAWN_RATE=${params.spawn_rate} \\
                          AUDIT_LOSS_THRESHOLD_PCT=${params.loss_threshold}
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'results/*', allowEmptyArchive: true
                    sh 'docker compose rm -sf'
                }
            }
        }

    }
}
