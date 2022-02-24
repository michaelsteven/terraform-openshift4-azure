#!/bin/bash

set -e

eval "$(./jq -r '@sh "export BEARER_TOKEN=\(.bearer_token) OPENSHIFT_VERSION=\(.openshift_version) SUBSCRIPTION_ID=\(.subscription_id) RESOURCE_GROUP_NAME=\(.resource_group_name)"')"

AZURE_ENDPOINT_DISK_STATE='https://management.azure.com/subscriptions/'${SUBSCRIPTION_ID}'/resourceGroups/'${RESOURCE_GROUP_NAME}'/providers/Microsoft.Compute/disks/coreos-'${OPENSHIFT_VERSION}'-vhd?api-version=2020-12-01'
AZURE_RESPONSE_DISK_STATE=$(curl -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" ${AZURE_ENDPOINT_DISK_STATE})

DISK_STATE=$(echo ${AZURE_RESPONSE_DISK_STATE} | ./jq -r '(.properties.diskState)' )

if [[ "${DISK_STATE}" == "ReadyToUpload" ]] || [[ "${DISK_STATE}" == "ActiveUpload" ]]; then
  AZURE_ENDPOINT='https://management.azure.com/subscriptions/'${SUBSCRIPTION_ID}'/resourceGroups/'${RESOURCE_GROUP_NAME}'/providers/Microsoft.Compute/disks/coreos-'${OPENSHIFT_VERSION}'-vhd/beginGetAccess?api-version=2020-12-01'
  AZURE_DATA='{"access":"Write","durationInSeconds":86400}'
  AZURE_RESPONSE=$(curl -i -X POST -H "Authorization: Bearer ${BEARER_TOKEN}" -H 'Content-Type:application/json' -H 'Accept:application/json' -d ${AZURE_DATA} ${AZURE_ENDPOINT})
  HTTP_RETURN_CODE=$(echo ${AZURE_RESPONSE} | ./jq -R -s 'split(" ")' | ./jq -r '.[1]' )
  if [[ "${HTTP_RETURN_CODE}" == "200" ]]; then
    DISK_SAS=$(echo ${AZURE_RESPONSE} | grep accessSAS | ./jq -r '(.accessSAS)' )
  elif [[ "${HTTP_RETURN_CODE}" == "202" ]]; then
    AZURE_ASYNC_OPERATION_ENDPOINT=$(echo ${AZURE_RESPONSE} | ./jq -R -s 'split("\r")' | grep azure-asyncoperation | ./jq -R -s 'split(": ")' | ./jq -r '.[1]' | tr -d '",' )
    sleep 20
    AZURE_ASYNC_OPERATION_RESPONSE=$(curl -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" ${AZURE_ASYNC_OPERATION_ENDPOINT})
    DISK_SAS=$(echo ${AZURE_ASYNC_OPERATION_RESPONSE} | ./jq -r '(.properties.output.accessSAS)' )
  else
    DISK_SAS=""
  fi
  RESPONSE_JSON=$(./jq -n --arg accessSas "${DISK_SAS}" '{"accessSas":$accessSas}')
else
  RESPONSE_JSON='{"accessSas": ""}'
fi

echo ${RESPONSE_JSON}