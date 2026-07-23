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
        booleanParam(name: 'OVERRIDE_BUILD_FAILURE_NOTIFICATION', defaultValue: true, description: 'Override the build failure notification')
        choice(name: 'environment', choices: ['staging', 'qa'], description: 'Named test environment')
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
                        staging: 'https://transaction-engine-lb.staging.tax.service.gov.uk',
                        qa     : 'https://transaction-engine-lb.qa.tax.service.gov.uk'
                    ]
                    def locust_host = envHosts[params.environment]

                    sh """#!/bin/bash -e
                        ${awsEnv(params.environment)}
                        NUMBER_OF_CORES=`nproc`

                        CLOUDFRONT_HEADER=$(aws ssm get-parameter \
                         --name /isc/www/cloudfront-request-header \
                         --with-decryption \
                         --query Parameter.Value \
                         --output text)

                        make test \\
                         LOCUST_HOST="${locust_host}" \\
                         CLOUDFRONT_HEADER="\${CLOUDFRONT_HEADER}" \\
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
                    sh 'DOCKER_UID=`id -u` docker compose rm -sf'
                }
            }
        }

    }
}
