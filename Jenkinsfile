def fetchAgentPodName() {
  return sh(
    returnStdout: true,
    script: 'kubectl get pods -n cloudbees-sda --field-selector=status.phase=Running --selector=jenkins -o jsonpath="{.items[0].metadata.name}"'
  ).trim()
}

pipeline {
  agent none
  options {
    timeout(time: 25, unit: 'MINUTES')
  }

  stages {
    stage('Checkout') {
      agent {
        kubernetes {
          label 'default-jnlp'
          defaultContainer 'jnlp'
          yamlFile 'jenkins-agent.yaml'
        }
      }

      steps {
        // Checkout source code
        checkout scm
      }
    }
    
    stage('Setup Python') {
      agent {
        kubernetes {
          label 'cml-dvc'
          defaultContainer 'cml-dvc-custom'
          yamlFile 'jenkins-agent.yaml'
        }
      }

      environment {
        XDG_CACHE_HOME = "${env.HOME}/.pip/cache"
      }
  
      steps {
        // Setup Python environment
        sh 'mkdir -p venv' // Create a directory for the virtual environment
        sh 'python3 -m venv --clear venv' // Create the virtual environment in the 'venv' directory
        sh 'chmod +x venv/bin/activate' // Make the activate script executable
        sh '. venv/bin/activate' // Execute the activate script
        script {
          def agentPodName = fetchAgentPodName()
        
        // Create the .pip directory if it doesn't exist
        sh "kubectl exec -ti -n cloudbees-sda ${agentPodName} -- mkdir -p /home/jenkins/.pip"
        // Set ownership and permissions for cache directory
        sh "kubectl exec -ti -n cloudbees-sda ${agentPodName} -- chown -R 1000:1000 /home/jenkins/.pip"
        sh "kubectl exec -ti -n cloudbees-sda ${agentPodName} -- chmod -R 755 /home/jenkins/.pip/cache"
        
        sh 'python -m pip install --upgrade pip' // Upgrade pip
        // Install dependencies with the --user flag
        sh 'python -m pip install --user -r requirements.txt'
      }
     }
    }
    stage('Setup CML') {
      agent {
        kubernetes {
          label 'cml-dvc'
          defaultContainer 'cml-dvc'
          yamlFile 'jenkins-agent.yaml'
        }
      }

      steps {
        // Setup CML
        sh 'cml-runner.py setup'
      }
    }
    
    stage('Setup DVC') {
      agent {
        kubernetes {
          label 'cml-dvc'
          defaultContainer 'cml-dvc'
          yamlFile 'jenkins-agent.yaml'
        }
      }

      steps {
        sh 'dvc init --no-scm'
        sh 'dvc remote add -d storage s3://ikurtz-cbci-aws-workshop-dml-demo/'
        sh 'dvc remote modify storage sso_profile cloudbees-sa-infra-admin'
      }
    }
    
    stage('Train model') {
      agent {
        kubernetes {
          label 'cml-dvc'
          defaultContainer 'cml-dvc'
          yamlFile 'jenkins-agent.yaml'
        }
      }
      
      steps {
        withAWS(region: 'us-east-1', profile: 'cloudbees-sa-infra-admin') {
          sh '''
            pip install -r requirements.txt  # Install dependencies
            dvc pull data --run-cache        # Pull data & run-cache from S3
            dvc repro                        # Reproduce pipeline
          '''
        }
      }
    }
    
    stage('Create CML report') {
      environment {
        REPO_TOKEN = credentials('ikurtz-gh-pat')
      }
      
      steps {
        container('cml-dvc') {
          sh 'echo "## Metrics: workflow vs. main" >> report.md'
          sh 'git fetch --depth=1 origin main:main'
        
          sh 'dvc metrics diff master --show-md >> report.md'
          sh 'echo "## Plots" >> report.md'
          sh 'echo "### Class confusions" >> report.md'
          sh 'dvc plots diff --target classes.csv --template confusion -x actual -y predicted --show-vega master > vega.json'
          sh 'vl2png vega.json -s 1.5 > plot.png'
          sh 'echo \'![](./plot.png "Confusion Matrix")\' >> report.md'
        
          sh 'echo "### Effects of regularization" >> report.md'
          sh 'dvc plots diff --target estimators.csv -x Regularization --show-vega master > vega.json'
          sh 'vl2png vega.json -s 1.5 > plot-diff.png'
          sh 'echo \'![](./plot-diff.png)\' >> report.md'
        
          sh 'echo "### Training loss" >> report.md'
          sh 'dvc plots diff --target loss.csv --show-vega main > vega.json'
          sh 'vl2png vega.json > plot-loss.png'
          sh 'echo \'![](./plot-loss.png "Training Loss")\' >> report.md'
        
          sh 'cml comment create report.md'
        }
      }
    }
  }
}



