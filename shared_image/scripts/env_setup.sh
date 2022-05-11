#!/bin/bash
set -e

function install_jq() {
  if [[ ! -f ${INSTALLER_WORKSPACE}jq ]]; then
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
}

function install_openshift_installer() {
  if [[ ! -f ${INSTALLER_WORKSPACE}openshift-install ]]; then
    case $(uname -s) in
      Darwin)
        wget -r -l1 -np -nd -q '${OPENSHIFT_INSTALLER_URL}/${OPENSHIFT_VERSION}/' -P ${INSTALLER_WORKSPACE} -A 'openshift-install-mac-4*.tar.gz'
        tar zxvf ${INSTALLER_WORKSPACE}/openshift-install-mac-4*.tar.gz -C ${INSTALLER_WORKSPACE}
        ;;
      Linux)
        wget -r -l1 -np -nd -q ${OPENSHIFT_INSTALLER_URL}/${OPENSHIFT_VERSION}/openshift-install-linux-${OPENSHIFT_VERSION}.tar.gz -P ${INSTALLER_WORKSPACE} 
        tar zxvf ${INSTALLER_WORKSPACE}openshift-install-linux-4*.tar.gz -C ${INSTALLER_WORKSPACE}
        ;;
      *)
        exit 1;;
    esac
    chmod u+x ${INSTALLER_WORKSPACE}openshift-install
    rm -f ${INSTALLER_WORKSPACE}*.tar.gz ${INSTALLER_WORKSPACE}README.md
  fi
}

test -e ${INSTALLER_WORKSPACE} || mkdir -p ${INSTALLER_WORKSPACE}

install_jq
if [[ $? -ne 0 ]]; then exit 1; fi

install_openshift_installer
if [[ $? -ne 0 ]]; then exit 1; fi

