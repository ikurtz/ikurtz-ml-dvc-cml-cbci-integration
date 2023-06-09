pipeline {
  agent 'none'
  options {
    timeout(time: 25, unit: 'MINUTES')
  }
  
  environment {
    AWS_SSO_CONFIGMAP = 'ikurtz-aws-sso-config-map'
  }

  stages {
    stage('Checkout') {
      agent {
        kubernetes {
          label 'default-jnlp'
          defaultContainer 'jnlp'
          namespace 'cloudbees-sda'
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
                  command: ['sh', '-c', 'sleep infinity']
                  tty: true
                  volumeMounts:
                    - name: ikurtz-aws-sso-config
                      mountPath: /root/.aws/config
                      readOnly: true
              volumes:
                - name: ikurtz-aws-sso-config
                  configMap:
                    name: ${AWS_SSO_CONFIGMAP}
            """
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
          label 'default-jnlp'
          defaultContainer 'cml-dvc'
          namespace 'cloudbees-sda'
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
                  command: ['sh', '-c', 'sleep infinity']
                  tty: true
                  volumeMounts:
                    - name: ikurtz-aws-sso-config
                      mountPath: /root/.aws/config
                      readOnly: true
              volumes:
                - name: ikurtz-aws-sso-config
                  configMap:
                    name: ${AWS_SSO_CONFIGMAP}
            """
        }
      }

      steps {
        // Setup Python environment
        sh 'python -m ensurepip'  // Install pip if available
        sh 'python -m pip --version || curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python get-pip.py'  // Install pip if not available
        sh 'python -m venv venv'
        sh 'source venv/bin/activate'
      }
    }
    
    stage('Setup CML') {
      agent {
        kubernetes {
          label 'default-jnlp'
          defaultContainer 'cml-dvc'
          namespace 'cloudbees-sda'
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
                  command: ['sh', '-c', 'sleep infinity']
                  tty: true
                  volumeMounts:
                    - name: ikurtz-aws-sso-config
                      mountPath: /root/.aws/config
                      readOnly: true
              volumes:
                - name: ikurtz-aws-sso-config
                  configMap:
                    name: ${AWS_SSO_CONFIGMAP}
            """
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
                  command: ['sh', '-c', 'sleep infinity']
                  tty: true
                  volumeMounts:
                    - name: ikurtz-aws-sso-config
                      mountPath: /root/.aws/config
                      subPath: config
                      readOnly: true
              volumes:
                - name: ikurtz-aws-sso-config
                  configMap:
                    name: ${AWS_SSO_CONFIGMAP}
            """
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
                  command: ['sh', '-c', 'sleep infinity']
                  tty: true
                  volumeMounts:
                    - name: ikurtz-aws-sso-config
                      mountPath: /root/.aws/config
                      subPath: config
                      readOnly: true
              volumes:
                - name: ikurtz-aws-sso-config
                  configMap:
                    name: ${AWS_SSO_CONFIGMAP}
            """
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


