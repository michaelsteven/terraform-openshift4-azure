#!/bin/bash

eval "$(./jq -r '@sh "export OPENSHIFT_VERSION=\(.openshift_version) RESOURCE_GROUP_NAME=\(.resource_group_name)"')"

DISK_STATE=$(az disk show -n "coreos-${OPENSHIFT_VERSION}-vhd" -g "${RESOURCE_GROUP_NAME}" --query diskState | tr -d '"')

if [[ "${DISK_STATE}" == "ReadyToUpload" ]] || [[ "${DISK_STATE}" == "ActiveUpload" ]]; then
  DISK_SAS=$(az disk grant-access -n "coreos-${OPENSHIFT_VERSION}-vhd" -g "${RESOURCE_GROUP_NAME}" --access-level Write --duration-in-seconds 86400)
else
  DISK_SAS='{"accessSas": ""}'
fi

echo ${DISK_SAS}