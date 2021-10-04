pipeline {
    agent any

    stages {
        // according to my tests, license files are not really needed for non-clustered sharded setup, despite what documentation says
        stage("Create License Files") {
            steps {
                withCredentials([file(credentialsId: 'ALFRESCO_LICENSE51', variable: 'alfrescolicense51'),
                                 file(credentialsId: 'ALFRESCO_LICENSE52', variable: 'alfrescolicense52'),
                                 file(credentialsId: 'ALFRESCO_LICENSE61', variable: 'alfrescolicense61')]) {
                    sh "cp \"\${alfrescolicense51}\" src/integrationTest/resources/license51/license.lic ; chmod +w src/integrationTest/resources/license51/license.lic ; chmod o+r src/integrationTest/resources/license51/license.lic"
                    sh "cp \"\${alfrescolicense52}\" src/integrationTest/resources/license52/license.lic ; chmod +w src/integrationTest/resources/license52/license.lic ; chmod o+r src/integrationTest/resources/license52/license.lic"
                    sh "cp \"\${alfrescolicense61}\" src/integrationTest/resources/license61/license.lic ; chmod +w src/integrationTest/resources/license61/license.lic ; chmod o+r src/integrationTest/resources/license61/license.lic"
                }
            }
        }

        stage("Build Docker Image") {
	    parallel {
		stage('Version solr4') {
		    environment {
			VERSIONS_TO_BUILD = "solr4"
		    }
		    steps {
			sh "./gradlew -Penterprise buildDockerImage"
		    }
		}
		stage('Version solr6') {
		    environment {
			VERSIONS_TO_BUILD = "solr6"
		    }
		    steps {
			sh "./gradlew -Penterprise buildDockerImage"
		    }
		}		
            }
	}

        stage("Integration Tests") {
	    parallel {
		stage('Version solr4') {
		    environment {
			VERSIONS_TO_BUILD = "solr4"
		    }
		    steps {
			sh "./gradlew -Penterprise integrationTests --info"
		    }
		    post {
			always {
			    sh "./gradlew -Penterprise composeDownAll"
			}
		    }
		}
		stage('Version solr6') {
		    environment {
			VERSIONS_TO_BUILD = "solr6"
		    }
		    steps {
			sh "./gradlew -Penterprise integrationTests --info"
		    }
		    post {
			always {
			    sh "./gradlew -Penterprise composeDownAll"
			}
		    }
		}
	    }
        }
        
        stage("Publish Docker Image") {
            when {
                anyOf {
                    branch 'master'
                    branch 'release*'
                }
            }
            steps {
                sh "./gradlew -Penterprise pushDockerImage"
            }
        }
    }

post {
        failure {
            emailext body: "${currentBuild.currentResult}: Job ${env.JOB_NAME} build ${env.BUILD_NUMBER}\n More info at: ${env.BUILD_URL}",
                recipientProviders: [[$class: 'DevelopersRecipientProvider'], [$class: 'RequesterRecipientProvider']],
                subject: "Jenkins Build ${currentBuild.currentResult}: Job ${env.JOB_NAME}"             
        }
    }
}
