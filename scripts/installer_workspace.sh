#!/bin/bash
set -e

function install_deps() {
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

if [[ ! -d ${INSTALLER_WORKSPACE} ]]; then
  mkdir -p ${INSTALLER_WORKSPACE}
fi

install_deps
