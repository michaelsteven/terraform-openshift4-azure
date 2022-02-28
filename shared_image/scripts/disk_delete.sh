#!/bin/bash

set -e

function install_deps() {
  if [[ ! -f ${INSTALLER_WORKSPACE}jq ]]; then 
    case $(uname -s) in
    Darwin)
      wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64 -O ${INSTALLER_WORKSPACE}jq > /dev/null 2>&1
      ;;
    Linux)
      wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O ${INSTALLER_WORKSPACE}jq > /dev/null 2>&1
      ;;
    *)
      exit 1;;
    esac
    chmod u+x ${INSTALLER_WORKSPACE}jq
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

function delete_managed_disk() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd?api-version=2020-12-01"
  local http_request_data=""

  local http_response=$(curl -sSi -X DELETE -H "Authorization: Bearer ${BEARER_TOKEN}" -H 'Content-Type:application/json' -H 'Accept:application/json' -d "${http_request_data}" "${http_endpoint}")
  local http_header=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[0]' )
  local http_body=$(echo "${http_response}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r\n\r\n")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )
  local http_return_code=$(echo "${http_header}" | grep -i HTTP | ${INSTALLER_WORKSPACE}jq -R -s 'split(" ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' )

  echo "${http_return_code}"
}

install_deps
BEARER_TOKEN=$(get_bearer_token)
DELETE_RETURN_CODE=$(delete_managed_disk)
