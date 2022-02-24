#!/bin/bash

set -e

eval "$(./jq -r '@sh "export BEARER_TOKEN=\(.bearer_token) OPENSHIFT_VERSION=\(.openshift_version) SUBSCRIPTION_ID=\(.subscription_id) RESOURCE_GROUP_NAME=\(.resource_group_name) REGION=\(.region) RHCOS_IMAGE_URL=\(.rhcos_image_url)"')"

AZURE_ENDPOINT='https://management.azure.com/subscriptions/'${SUBSCRIPTION_ID}'/resourceGroups/'${RESOURCE_GROUP_NAME}'/providers/Microsoft.Compute/disks/coreos-'${OPENSHIFT_VERSION}'-vhd?api-version=2020-12-01'
DISK_SIZE_BYTES=$(curl -sI ${RHCOS_IMAGE_URL} | grep -i Content-Length | awk '{print $2}')
AZURE_DATA='{"location":"'${REGION}'","properties":{"osType":"Linux","creationData":{"createOption":"Upload","uploadSizeBytes":'${DISK_SIZE_BYTES}'}}}'

AZURE_RESPONSE=$(curl -X PUT -H "Authorization: Bearer ${BEARER_TOKEN}" -H 'Content-Type:application/json' -H 'Accept:application/json' -d ${AZURE_DATA} ${AZURE_ENDPOINT})
DISK_NAME=$(echo ${AZURE_RESPONSE} | ./jq -r '(.name)' )

RESPONSE_JSON=$(./jq -n --arg disk_name "${DISK_NAME}" '{"disk_name":$disk_name}')

echo ${RESPONSE_JSON}