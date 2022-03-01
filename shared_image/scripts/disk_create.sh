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

  if [[ ! -f ${INSTALLER_WORKSPACE}azcopy ]]; then 
    case $(uname -s) in
    Darwin)
      curl -L https://aka.ms/downloadazcopy-v10-mac  -o ${INSTALLER_WORKSPACE}downloadazcopy-v10-mac.zip
      unzip -j -d ${INSTALLER_WORKSPACE} ${INSTALLER_WORKSPACE}downloadazcopy-v10-mac.zip */azcopy
      ;;
    Linux)
      curl -L https://aka.ms/downloadazcopy-v10-linux -o ${INSTALLER_WORKSPACE}downloadazcopy-v10-linux
      tar zxvf ${INSTALLER_WORKSPACE}downloadazcopy-v10-linux -C ${INSTALLER_WORKSPACE} --wildcards *azcopy --strip-components 1
      ;;
    *)
      exit 1;;
    esac
    chmod u+x ${INSTALLER_WORKSPACE}azcopy
  fi
}

function get_bearer_token() {
  local http_endpoint="https://login.microsoftonline.com/${TENANT_ID}/oauth2/token?api-version=1.0"
  local http_request_data="grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&resource=https%3A%2F%2Fmanagement.azure.com%2F"

  local http_response=$(curl -sSi -X POST -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept:application/json' -d "${http_request_data}" "${http_endpoint}")
  local http_header=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[0]' )
  local http_body=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )
  local http_return_code=$(echo "${http_header}" | grep -i HTTP | ${INSTALLER_WORKSPACE}jq -R -s 'split(" ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )

  if [[ "${http_return_code}" == 200 ]]; then
    local access_token=$(echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.access_token)')
  else
    local access_token=
  fi

  echo "${access_token}"
}

function create_managed_disk() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd?api-version=2020-12-01"
  local disk_size_bytes=$(curl -sSI -X GET "${RHCOS_IMAGE_URL}" | grep -i Content-Length | ${INSTALLER_WORKSPACE}jq -R -s 'split(" ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )
  local http_request_data='{"location":"'${REGION}'","properties":{"osType":"Linux","creationData":{"createOption":"Upload","uploadSizeBytes":'${disk_size_bytes}'}}}'

  local http_response=$(curl -sSi -X PUT -H "Authorization: Bearer ${BEARER_TOKEN}" -H 'Content-Type:application/json' -H 'Accept:application/json' -d "${http_request_data}" "${http_endpoint}")
  local http_header=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[0]' )
  local http_body=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )
  local http_return_code=$(echo "${http_header}" | grep -i HTTP | ${INSTALLER_WORKSPACE}jq -R -s 'split(" ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )

  if [[ "${http_return_code}" == 200 || "${http_return_code}" == 202 ]]; then
    local disk_name=$(echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.name)')
  else
    local disk_name=
  fi

  echo "${disk_name}"
}

function get_disk_state() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd?api-version=2020-12-01"

  local http_response=$(curl -sSi -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" "${http_endpoint}")
  local http_header=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[0]' )
  local http_body=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )
  local http_return_code=$(echo "${http_header}" | grep -i HTTP | ${INSTALLER_WORKSPACE}jq -R -s 'split(" ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )

  if [[ "${http_return_code}" == 200 || "${http_return_code}" == 202 ]]; then
    local disk_state=$(echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.properties.diskState)')
  else
    local disk_state=
  fi

  echo "${disk_state}"
}

function get_access_sas() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd/beginGetAccess?api-version=2020-12-01"
  local http_request_data='{"access":"Write","durationInSeconds":86400}'

  
  local http_response=$(curl -sSi -X POST -H "Authorization: Bearer ${BEARER_TOKEN}" -H 'Content-Type:application/json' -H 'Accept:application/json' -d "${http_request_data}" "${http_endpoint}")
  local http_header=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[0]' )
  local http_body=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )
  local http_return_code=$(echo "${http_header}" | grep -i HTTP | ${INSTALLER_WORKSPACE}jq -R -s 'split(" ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )

  if [[ "${http_return_code}" == 200 ]]; then
    local access_sas=$(echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.accessSAS)' )
  elif [[ "${http_return_code}" == 202 ]]; then
    local operation_endpoint=$(echo "${http_header}" | grep -i azure-asyncoperation | ${INSTALLER_WORKSPACE}jq -R -s 'split(": ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' | tr -d '\r')
    sleep 20
    local operation_response=$(curl -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" "${operation_endpoint}")
    local access_sas=$(echo "${operation_response}" | ${INSTALLER_WORKSPACE}jq -r '(.properties.output.accessSAS)' )
  else
    local access_sas=
  fi

  echo "${access_sas}"
}

function rhcos_disk_copy() {
  "${INSTALLER_WORKSPACE}azcopy" copy "${RHCOS_IMAGE_URL}" "${ACCESS_SAS}" --blob-type PageBlob
}

function revoke_access_sas() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd/endGetAccess?api-version=2020-12-01"

  local http_response=$(curl -sSi -X POST -H "Authorization: Bearer ${BEARER_TOKEN}" -d "" "${http_endpoint}")
  local http_header=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[0]' )
  local http_body=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )
  local http_return_code=$(echo "${http_header}" | grep -i HTTP | ${INSTALLER_WORKSPACE}jq -R -s 'split(" ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )
}

install_deps
BEARER_TOKEN=$(get_bearer_token)
MANAGED_DISK_NAME=$(create_managed_disk)
DISK_STATE=$(get_disk_state)
if [[ "${DISK_STATE}" == "ReadyToUpload" ]] || [[ "${DISK_STATE}" == "ActiveUpload" ]]; then
  ACCESS_SAS=$(get_access_sas)
  if [[ ! -z $ACCESS_SAS ]]; then
    rhcos_disk_copy
    revoke_access_sas
    sleep 20
  else
    exit 1
  fi
fi
