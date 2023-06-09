pipeline {
  agent {
    kubernetes {
      label 'my-kubernetes-label'
      defaultContainer 'default-jnlp'
      yaml """
        apiVersion: v1
        kind: Pod
        metadata:
          labels:
            my-kubernetes-label: true
        spec:
          containers:
            - name: cml-dvc
              image: 268150017804.dkr.ecr.us-east-1.amazonaws.com/cbci-aws-workshop-registry/cml:0-dvc2-base1
              command: ['cat']
              tty: true
          """
    }
  }
  
  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
    
    stage('Setup Python') {
      steps {
        container('cml-dvc') {
          tool 'Python 3.x'
        }
      }
    }
    
    stage('Setup CML') {
      steps {
        container('cml-dvc') {
          sh 'cml-runner.py setup'
        }
      }
    }
    
    stage('Setup DVC') {
      steps {
        container('cml-dvc') {
          sh 'dvc init --no-scm'
          sh 'dvc remote add -d storage s3://your-bucket/path'
          sh 'dvc remote modify storage credentialpath /app/.aws/credentials'
        }
      }
    }
    
    stage('Train model') {
      environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
      }
      steps {
        container('cml-dvc') {
          sh 'pip install -r requirements.txt'
          sh 'dvc pull data --run-cache'
          sh 'dvc repro'
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

