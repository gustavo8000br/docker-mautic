pipeline {
  agent {
    label 'X86-64-MULTI'
  }
  // Configuration for the variables used for this specific repo
  environment {
    BUILDS_DISCORD=credentials('build_webhook_url')
    GITHUB_TOKEN=credentials('498b4638-2d04-4ce5-832d-8a57d01d97ac')
    EXT_USER = 'gustavo8000br'
    EXT_REPO = 'docker-mautic'
    CONTAINER_NAME = 'docker-mautic'
    LS_USER = 'gustavo8000br'
    LS_REPO = 'docker-mautic'
    DOCKERHUB_IMAGE = 'gustavo8000br/docker-mautic'
    DIST_IMAGE = 'ubuntu'
    MULTIARCH='true'
	  CI='false'
  }
  stages {
    // Setup all the basic environment variables needed for the build
    stage("Set ENV Variables base"){
      steps{
        script{
          env.EXIT_STATUS = ''
          env.LS_RELEASE = sh(
            script: '''docker run --rm alexeiled/skopeo sh -c 'skopeo inspect docker://docker.io/'${DOCKERHUB_IMAGE}':latest 2>/dev/null' | jq -r '.Labels.build_version' | awk '{print $3}' | grep '\\-ls' || : ''',
            returnStdout: true).trim()
          env.GITHUB_DATE = sh(
            script: '''date '+%Y-%m-%dT%H:%M:%S%:z' ''',
            returnStdout: true).trim()
          env.COMMIT_SHA = sh(
            script: '''git rev-parse HEAD''',
            returnStdout: true).trim()
          env.CODE_URL = 'https://github.com/' + env.LS_USER + '/' + env.LS_REPO + '/commit/' + env.GIT_COMMIT
          env.DOCKERHUB_LINK = 'https://hub.docker.com/r/' + env.DOCKERHUB_IMAGE + '/tags/'
          env.PULL_REQUEST = env.CHANGE_ID
          env.LICENSE_TAG = sh(
            script: '''#!/bin/bash
                       if [ -e LICENSE ] ; then
                         cat LICENSE | md5sum | cut -c1-8
                       else
                         echo none
                       fi''',
            returnStdout: true).trim()
        }
        script{
          env.LS_RELEASE_NUMBER = sh(
            script: '''echo ${LS_RELEASE} |sed 's/^.*-ls//g' ''',
            returnStdout: true).trim()
        }
        script{
          env.LS_TAG_NUMBER = sh(
            script: '''#! /bin/bash
                       tagsha=$(git rev-list -n 1 ${LS_RELEASE} 2>/dev/null)
                       if [ "${tagsha}" == "${COMMIT_SHA}" ]; then
                         echo ${LS_RELEASE_NUMBER}
                       elif [ -z "${GIT_COMMIT}" ]; then
                         echo ${LS_RELEASE_NUMBER}
                       else
                         echo $((${LS_RELEASE_NUMBER} + 1))
                       fi''',
            returnStdout: true).trim()
        }
      }
    }
    /* ########################
       External Release Tagging
       ######################## */
    // If this is a stable github release use the latest endpoint from github to determine the ext tag
    stage("Set ENV github_stable"){
     steps{
       script{
         env.EXT_RELEASE = sh(
           script: '''curl -s https://api.github.com/repos/${EXT_USER}/${EXT_REPO}/releases/latest | jq -r '. | .tag_name' ''',
           returnStdout: true).trim()
       }
     }
    }
    // If this is a stable or devel github release generate the link for the build message
    stage("Set ENV github_link"){
     steps{
       script{
         env.RELEASE_LINK = 'https://github.com/' + env.EXT_USER + '/' + env.EXT_REPO + '/releases/tag/' + env.EXT_RELEASE
       }
     }
    }
    // Sanitize the release tag and strip illegal docker or github characters
    stage("Sanitize tag"){
      steps{
        script{
          env.EXT_RELEASE_CLEAN = sh(
            script: '''echo ${EXT_RELEASE} | sed 's/[~,%@+;:/]//g' ''',
            returnStdout: true).trim()
        }
      }
    }
    // If this is a master build use live docker endpoints
    stage("Set ENV live build"){
      when {
        branch "master"
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.IMAGE = env.DOCKERHUB_IMAGE
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER + '|arm32v7-' + env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
          }
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
        }
      }
    }
    // If this is a dev build use dev docker endpoints
    stage("Set ENV dev build"){
      when {
        not {branch "master"}
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.IMAGE = env.DEV_DOCKERHUB_IMAGE
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '|arm32v7-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          }
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          env.DOCKERHUB_LINK = 'https://hub.docker.com/r/' + env.DEV_DOCKERHUB_IMAGE + '/tags/'
        }
      }
    }
    /* ###############
       Build Container
       ############### */
    // Build Docker container for push to LS Repo
    stage('Build-Single') {
      when {
        environment name: 'MULTIARCH', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh "docker build --no-cache --pull -t ${IMAGE}:${META_TAG} \
        --build-arg VERSION=\"${META_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} 'beta-fpm'"
      }
    }
    // Build MultiArch Docker containers for push to LS Repo
    stage('Build-Multi') {
      when {
        environment name: 'MULTIARCH', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      parallel {
        stage('Build X86') {
          steps {
            sh "docker build --no-cache --pull -t ${IMAGE}:amd64-beta-fpm-${META_TAG} \
            --build-arg VERSION=\"${META_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} 'beta-fpm'"
          }
        }
        stage('Build ARMHF') {
          agent {
            label 'ARMHF'
          }
          steps {
            withCredentials([
              [
                $class: 'UsernamePasswordMultiBinding',
                credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
                usernameVariable: 'DOCKERUSER',
                passwordVariable: 'DOCKERPASS'
              ]
            ]) {
              echo 'Logging into DockerHub'
              sh '''#! /bin/bash
                 echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
                 '''
              sh "docker build --no-cache --pull -f Dockerfile.armhf -t ${IMAGE}:arm32v7-beta-fpm-${META_TAG} \
                        --build-arg VERSION=\"${META_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} 'beta-fpm'"
              sh "docker tag ${IMAGE}:arm32v7-beta-fpm-${META_TAG} $DOCKERUSER/buildcache:arm32v7-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER}"
              sh "docker push $DOCKERUSER/buildcache:arm32v7-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER}"
              sh '''docker rmi \
                    ${IMAGE}:arm32v7-beta-fpm-${META_TAG} \
                    $DOCKERUSER/buildcache:arm32v7-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER} || :'''
            }
          }
        }
        stage('Build ARM64') {
          agent {
            label 'ARM64'
          }
          steps {
            withCredentials([
              [
                $class: 'UsernamePasswordMultiBinding',
                credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
                usernameVariable: 'DOCKERUSER',
                passwordVariable: 'DOCKERPASS'
              ]
            ]) {
              echo 'Logging into DockerHub'
              sh '''#! /bin/bash
                 echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
                 '''
              sh "docker build --no-cache --pull -f Dockerfile.aarch64 -t ${IMAGE}:arm64v8-beta-fpm-${META_TAG} \
                        --build-arg VERSION=\"${META_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} 'beta-fpm'"
              sh "docker tag ${IMAGE}:arm64v8-beta-fpm-${META_TAG} $DOCKERUSER/buildcache:arm64v8-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER}"
              sh "docker push $DOCKERUSER/buildcache:arm64v8-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER}"
              sh '''docker rmi \
                    ${IMAGE}:arm64v8-beta-fpm-${META_TAG} \
                    $DOCKERUSER/buildcache:arm64v8-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER} || :'''
            }
          }
        }
      }
    }
    /* ##################
         Release Logic
       ################## */
    // If this is an amd64 only image only push a single image
    stage('Docker-Push-Single') {
      when {
        environment name: 'MULTIARCH', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          echo 'Logging into DockerHub'
          sh '''#! /bin/bash
             echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
             '''
          sh "docker tag ${IMAGE}:${META_TAG} ${IMAGE}:latest"
          sh "docker push ${IMAGE}:latest"
          sh "docker push ${IMAGE}:${META_TAG}"
          sh '''docker rmi \
                ${IMAGE}:${META_TAG} \
                ${IMAGE}:latest || :'''

        }
      }
    }
    // If this is a multi arch release push all images and define the manifest
    stage('Docker-Push-Multi') {
      when {
        environment name: 'MULTIARCH', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          sh '''#! /bin/bash
             echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
             '''
          sh '''#! /bin/bash
                if [ "${CI}" == "false" ]; then
                  docker pull $DOCKERUSER/buildcache:arm32v7-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER}
                  docker pull $DOCKERUSER/buildcache:arm64v8-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER}
                  docker tag $DOCKERUSER/buildcache:arm32v7-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm32v7-beta-fpm-${META_TAG}
                  docker tag $DOCKERUSER/buildcache:arm64v8-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm64v8-beta-fpm-${META_TAG}
                fi'''
          sh "docker tag ${IMAGE}:amd64-beta-fpm-${META_TAG} ${IMAGE}:amd64-beta-fpm-latest"
          sh "docker tag ${IMAGE}:arm32v7-${META_TAG} ${IMAGE}:arm32v7-beta-fpm-latest"
          sh "docker tag ${IMAGE}:arm64v8-${META_TAG} ${IMAGE}:arm64v8-beta-fpm-latest"
          sh "docker push ${IMAGE}:amd64-beta-fpm-${META_TAG}"
          sh "docker push ${IMAGE}:arm32v7-beta-fpm-${META_TAG}"
          sh "docker push ${IMAGE}:arm64v8-beta-fpm-${META_TAG}"
          sh "docker push ${IMAGE}:amd64-beta-fpm-latest"
          sh "docker push ${IMAGE}:arm32v7-beta-fpm-latest"
          sh "docker push ${IMAGE}:arm64v8-beta-fpm-latest"
          sh "docker manifest push --purge ${IMAGE}:latest || :"
          sh "docker manifest create ${IMAGE}:latest ${IMAGE}:amd64-beta-fpm-latest ${IMAGE}:arm32v7-beta-fpm-latest ${IMAGE}:arm64v8-beta-fpm-latest"
          sh "docker manifest annotate ${IMAGE}:latest ${IMAGE}:arm32v7-beta-fpm-latest --os linux --arch arm"
          sh "docker manifest annotate ${IMAGE}:latest ${IMAGE}:arm64v8-beta-fpm-latest --os linux --arch arm64 --variant v8"
          sh "docker manifest push --purge ${IMAGE}:${META_TAG} || :"
          sh "docker manifest create ${IMAGE}:${META_TAG} ${IMAGE}:amd64-beta-fpm-${META_TAG} ${IMAGE}:arm32v7-beta-fpm-${META_TAG} ${IMAGE}:arm64v8-beta-fpm-${META_TAG}"
          sh "docker manifest annotate ${IMAGE}:${META_TAG} ${IMAGE}:arm32v7-beta-fpm-${META_TAG} --os linux --arch arm"
          sh "docker manifest annotate ${IMAGE}:${META_TAG} ${IMAGE}:arm64v8-beta-fpm-${META_TAG} --os linux --arch arm64 --variant v8"
          sh "docker manifest push --purge ${IMAGE}:latest"
          sh "docker manifest push --purge ${IMAGE}:${META_TAG}"
          sh '''docker rmi \
                ${IMAGE}:amd64-beta-fpm-${META_TAG} \
                ${IMAGE}:amd64-beta-fpm-latest \
                ${IMAGE}:arm32v7-beta-fpm-${META_TAG} \
                ${IMAGE}:arm32v7-beta-fpm-latest \
                ${IMAGE}:arm64v8-beta-fpm-${META_TAG} \
                ${IMAGE}:arm64v8-beta-fpm-latest \
                $DOCKERUSER/buildcache:arm32v7-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER} \
                $DOCKERUSER/buildcache:arm64v8-beta-fpm-${COMMIT_SHA}-${BUILD_NUMBER} || :'''
        }
      }
    }
    // If this is a public release tag it in the LS Github
    stage('Github-Tag-Push-Release') {
      when {
        branch "master"
        expression {
          env.LS_RELEASE != env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
        }
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        echo "Pushing New tag for current commit ${EXT_RELEASE_CLEAN}-ls${LS_TAG_NUMBER}"
        sh '''curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${LS_USER}/${LS_REPO}/git/tags \
        -d '{"tag":"'${EXT_RELEASE_CLEAN}'-ls'${LS_TAG_NUMBER}'",\
             "object": "'${COMMIT_SHA}'",\
             "message": "Tagging Release '${EXT_RELEASE_CLEAN}'-ls'${LS_TAG_NUMBER}' to master",\
             "type": "commit",\
             "tagger": {"name": "Jenkins","email": "gustavo8000@icloud.com","date": "'${GITHUB_DATE}'"}}' '''
        echo "Pushing New release for Tag"
        sh '''#! /bin/bash
              curl -s https://api.github.com/repos/${EXT_USER}/${EXT_REPO}/releases/latest | jq '. |.body' | sed 's:^.\\(.*\\).$:\\1:' > releasebody.json
              echo '{"tag_name":"'${EXT_RELEASE_CLEAN}'-ls'${LS_TAG_NUMBER}'",\
                     "target_commitish": "master",\
                     "name": "'${EXT_RELEASE_CLEAN}'-ls'${LS_TAG_NUMBER}'",\
                     "body": "**Changes:**\\n\\n'${LS_RELEASE_NOTES}'\\n**'${EXT_REPO}' Changes:**\\n\\n' > start
              printf '","draft": false,"prerelease": true}' >> releasebody.json
              paste -d'\\0' start releasebody.json > releasebody.json.done
              curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${LS_USER}/${LS_REPO}/releases -d @releasebody.json.done'''
      }
    }
  }
  /* ######################
     Send status to Discord
     ###################### */
  post {
    always {
      script{
          if (env.EXIT_STATUS == "ABORTED"){
            sh 'echo "build aborted"'
          }
          else if (currentBuild.currentResult == "SUCCESS"){
            sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://s3-sa-east-1.amazonaws.com/overstack.codes/cicd-jenkins-assets/ninjenkins2.png","embeds": [{"color": 1681177,\
                    "description": "**Build:**  '${BUILD_NUMBER}'\\n**Status:**  Success\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n**DockerHub:** '${DOCKERHUB_LINK}'\\n"}],\
                    "username": "Jenkins"}' ${BUILDS_DISCORD} '''
          }
          else {
            sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://s3-sa-east-1.amazonaws.com/overstack.codes/cicd-jenkins-assets/fire-jenkins.png","embeds": [{"color": 16711680,\
                    "description": "**Build:**  '${BUILD_NUMBER}'\\n**Status:**  failure\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n**DockerHub:** '${DOCKERHUB_LINK}'\\n"}],\
                    "username": "Jenkins"}' ${BUILDS_DISCORD} '''
          }
        }
      // End script Send status to Discord
    }
  }
}
