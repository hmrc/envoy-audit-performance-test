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
