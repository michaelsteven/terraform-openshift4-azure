#!/bin/bash
set -e

function install_openshift_installer() {
  case $(uname -s) in
    Darwin)
      wget -r -l1 -np -nd -q 'https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_VERSION}/' -P ${INSTALLER_WORKSPACE} -A 'openshift-install-mac-4*.tar.gz'
      tar zxvf ${INSTALLER_WORKSPACE}/openshift-install-mac-4*.tar.gz -C ${INSTALLER_WORKSPACE}
      ;;
    Linux)
      wget -r -l1 -np -nd -q https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_VERSION}/openshift-install-linux-${OPENSHIFT_VERSION}.tar.gz -P ${INSTALLER_WORKSPACE} 
      tar zxvf ${INSTALLER_WORKSPACE}openshift-install-linux-4*.tar.gz -C ${INSTALLER_WORKSPACE}
      ;;
    *)
      exit 1;;
  esac
  rm -f ${INSTALLER_WORKSPACE}*.tar.gz ${INSTALLER_WORKSPACE}README.md
}

function install_openshift_client() {
  case $(uname -s) in
    Darwin)
      wget -r -l1 -np -nd -q 'https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_VERSION}/' -P ${INSTALLER_WORKSPACE} -A 'openshift-client-mac-4*.tar.gz'
      tar zxvf ${INSTALLER_WORKSPACE}/openshift-client-mac-4*.tar.gz -C ${INSTALLER_WORKSPACE}
      ;;
    Linux)
      wget -r -l1 -np -nd -q https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_VERSION}/openshift-client-linux-${OPENSHIFT_VERSION}.tar.gz -P ${INSTALLER_WORKSPACE}
      tar zxvf ${INSTALLER_WORKSPACE}openshift-client-linux-4*.tar.gz -C ${INSTALLER_WORKSPACE}
      ;;
    *)
      exit 1;;
  esac
  rm -f ${INSTALLER_WORKSPACE}*.tar.gz ${INSTALLER_WORKSPACE}README.md
}

function install_jq() {
  case $(uname -s) in
    Darwin)
      curl -sSL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64 -o ${INSTALLER_WORKSPACE}jq
      ;;
    Linux)
      curl -sSL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o ${INSTALLER_WORKSPACE}jq
      ;;
    *)
      exit 1;;
  esac
  chmod u+x ${INSTALLER_WORKSPACE}jq
}

function install_azcopy() {
  case $(uname -s) in
    Darwin)
      curl -L https://aka.ms/downloadazcopy-v10-mac  -o ${INSTALLER_WORKSPACE}/downloadazcopy-v10-mac.zip
      unzip -j -d ${INSTALLER_WORKSPACE} ${INSTALLER_WORKSPACE}/downloadazcopy-v10-mac.zip */azcopy
      rm -f ${INSTALLER_WORKSPACE}/downloadazcopy-v10-mac.zip
      ;;
    Linux)
      curl -L https://aka.ms/downloadazcopy-v10-linux -o ${INSTALLER_WORKSPACE}/downloadazcopy-v10-linux
      tar zxvf ${INSTALLER_WORKSPACE}downloadazcopy-v10-linux -C ${INSTALLER_WORKSPACE} --wildcards *azcopy --strip-components 1
      rm -f ${INSTALLER_WORKSPACE}downloadazcopy-v10-linux      
      ;;
    *)
      exit 1;;
  esac
}

test -e ${INSTALLER_WORKSPACE} || mkdir -p ${INSTALLER_WORKSPACE}

install_openshift_installer
install_openshift_client
install_jq
install_azcopy
