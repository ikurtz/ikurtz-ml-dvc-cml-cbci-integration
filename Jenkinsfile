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
          defaultContainer 'cml-dvc'
          yamlFile 'jenkins-agent.yaml'
        }
      }
      
      steps {
        // Setup Python environment
        sh 'curl https://pyenv.run | bash' // Install pyenv
        sh 'export PYENV_ROOT=/workspace/.pyenv'
        sh 'export PATH="$PYENV_ROOT/bin:$PATH"'
        sh 'eval "$(pyenv init --path)"'
        sh 'eval "$(pyenv virtualenv-init -)"'
        sh 'pyenv install 3.9.5' // Install Python version
        sh 'pyenv global 3.9.5' // Set the installed Python version as the default
        sh 'export VIRTUAL_ENV=/workspace/venv'
        sh 'export PATH="$VIRTUAL_ENV/bin:$PATH"'
        sh 'python -m venv $VIRTUAL_ENV' // Create a virtual environment
        sh 'source $VIRTUAL_ENV/bin/activate' // Activate the virtual environment
        sh 'python -m pip install --upgrade pip' // Upgrade pip
        sh 'python -m pip install -r requirements.txt' // Install dependencies
      }
    }
    
    stage('Setup CML') {
      agent {
        kubernetes {
          label 'default-jnlp'
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
          label 'default-jnlp'
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
          label 'default-jnlp'
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



