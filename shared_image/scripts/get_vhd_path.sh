#!/bin/bash
set -e

eval "$(./installer-files/jq -r '@sh "INSTALLER_WORKSPACE=\(.installer_workspace)"')"
  
VHD_URL=$(${INSTALLER_WORKSPACE}/openshift-install coreos print-stream-json | ${INSTALLER_WORKSPACE}/jq -r '.architectures.x86_64."rhel-coreos-extensions"."azure-disk".url')

${INSTALLER_WORKSPACE}/jq -n --arg VHD_URL "$VHD_URL" '{"VHD_URL":$VHD_URL}'