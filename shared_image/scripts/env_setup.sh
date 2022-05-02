#!/bin/bash
set -e

  if [[ ! -f ${INSTALLER_WORKSPACE}jq ]]; then 
    mkdir -p ${INSTALLER_WORKSPACE}
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
  fi

  if [[ ! -f ${INSTALLER_WORKSPACE}openshift-install ]]; then 
    mkdir -p ${INSTALLER_WORKSPACE}
    case $(uname -s) in
    Darwin)
      wget -r -l1 -np -nd -q ${installer_url} -P ${INSTALLER_WORKSPACE} -A 'openshift-install-mac-4*.tar.gz'
      tar zxvf ${INSTALLER_WORKSPACE}/openshift-install-mac-4*.tar.gz -C ${INSTALLER_WORKSPACE}
      ;;
    Linux)
      echo ${OCP_URL}openshift-install-linux-${openshift_version}.tar.gz
      wget -r -l1 -np -nd -q ${OCP_URL}openshift-install-linux-${openshift_version}.tar.gz -P ${INSTALLER_WORKSPACE} 
      tar zxvf ${INSTALLER_WORKSPACE}openshift-install-linux-4*.tar.gz -C ${INSTALLER_WORKSPACE}
      ;;
    *)
      exit 1;;
    esac
    chmod u+x ${INSTALLER_WORKSPACE}openshift-install
  fi
  
