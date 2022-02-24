#!/bin/bash

set -e

eval "$(./jq -r '@sh "export BEARER_TOKEN=\(.bearer_token) OPENSHIFT_VERSION=\(.openshift_version) SUBSCRIPTION_ID=\(.subscription_id) RESOURCE_GROUP_NAME=\(.resource_group_name)"')"

AZURE_ENDPOINT='https://management.azure.com/subscriptions/'${SUBSCRIPTION_ID}'/resourceGroups/'${RESOURCE_GROUP_NAME}'/providers/Microsoft.Compute/disks/coreos-'${OPENSHIFT_VERSION}'-vhd/endGetAccess?api-version=2020-12-01'

AZURE_RESPONSE=$(curl -X POST -H "Authorization: Bearer ${BEARER_TOKEN}" -d "" ${AZURE_ENDPOINT})
sleep 20

RESPONSE_JSON='{"revoke_access": "true"}'

echo ${RESPONSE_JSON}