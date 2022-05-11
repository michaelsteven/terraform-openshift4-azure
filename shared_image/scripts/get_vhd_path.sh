#!/bin/bash
set -e

STD_IN=$(</dev/stdin)
INSTALLER_WORKSPACE=$(echo ${STD_IN} | grep -oP '"installer_workspace":"\K[^"]+')
  
VHD_URL=$(${INSTALLER_WORKSPACE}/openshift-install coreos print-stream-json | ${INSTALLER_WORKSPACE}/jq -r '.architectures.x86_64."rhel-coreos-extensions"."azure-disk".url')

${INSTALLER_WORKSPACE}/jq -n --arg VHD_URL "$VHD_URL" '{"VHD_URL":$VHD_URL}'