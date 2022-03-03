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

function get_response_header() {
  local http_response_array=$(echo $1 | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r \r ")')
  local http_response_array_length=$(echo "${http_response_array}" | ${INSTALLER_WORKSPACE}jq length)

  local x=0
  local http_response_header=
  local http_found=
  local content_length_found=
  while [[ $x -lt "${http_response_array_length}" && (( -z "${http_found}" ) || ( -z "${content_length_found}" )) ]]; do
    http_response_header=$(echo "${http_response_array}" | ${INSTALLER_WORKSPACE}jq -r ".[$x]")
    http_found=$(echo "${http_response_header}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r")' | grep -i HTTP)
    content_length_found=$(echo "${http_response_header}" | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r")' | grep -i Content-Length)
    x=$(( $x + 1 ))
  done

  if [[ ( -z "${http_found}") || ( -z "${content_length_found}") ]]; then http_response_header= ; fi

  echo "${http_response_header}"
}

function get_response_body() {
  local http_response_array=$(echo $1 | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r \r ")')
  local http_response_array_length=$(echo "${http_response_array}" | ${INSTALLER_WORKSPACE}jq length)

  local x=0
  local http_response_body=
  local http_response_body_length=
  local last_char_index=
  local first_char=
  local last_char=
  while [[ $x -lt "${http_response_array_length}" && (( "${first_char}" != "{" ) || ( "${last_char}" != "}" )) ]]; do
    http_response_body=$(echo "${http_response_array}" | ${INSTALLER_WORKSPACE}jq -r ".[$x]" | tr -d '\r')
    http_response_body_length=$(echo "${http_response_body}" | wc -c )
    last_char_index=$(( $http_response_body_length - 2 ))
    first_char="${http_response_body:0:1}"
    last_char="${http_response_body:$last_char_index:1}"
    x=$(( $x + 1 ))
  done

  if [[ ( "${first_char}" != "{" ) || ( "${last_char}" != "}" ) ]]; then http_response_body= ; fi

  echo "${http_response_body}"
}

function get_http_return_code() {
  echo $1 | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r")' | grep HTTP | xargs | ${INSTALLER_WORKSPACE}jq -R -s 'split(" ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]'
}

function get_content_length() {
  echo $1 | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r")' | grep -i Content-Length | ${INSTALLER_WORKSPACE}jq -R -s 'split(": ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' | tr -d '",'
}

function get_operation_endpoint() {
  echo $1 | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r")' | grep -i azure-asyncoperation | ${INSTALLER_WORKSPACE}jq -R -s 'split(": ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' | tr -d '",'
}

function get_bearer_token() {
  local http_endpoint="https://login.microsoftonline.com/${TENANT_ID}/oauth2/token?api-version=1.0"
  local http_request_data="grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&resource=https%3A%2F%2Fmanagement.azure.com%2F"

  local http_response=$(curl -sSi -X POST -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept:application/json' -d "${http_request_data}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_body=$(get_response_body "${http_response}")
  if [[ -z "${http_body}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 ]]; then return 1; fi

  echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.access_token)'
}

function get_disk_size() {
  local http_endpoint=$1
  local http_response=$(curl -sSI -X GET "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 ]]; then return 1; fi

  echo $(get_content_length "${http_header}")
}

function create_managed_disk() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd?api-version=2020-12-01"
  
  local disk_size_bytes=$(get_disk_size "${RHCOS_IMAGE_URL}")
  if [[ -z "${disk_size_bytes}" || "${disk_size_bytes}" -lt 20972032 ]]; then return 1; fi

  local http_request_data='{"location":"'${REGION}'","properties":{"osType":"Linux","creationData":{"createOption":"Upload","uploadSizeBytes":'${disk_size_bytes}'}}}'

  local http_response=$(curl -sSi -X PUT -H "Authorization: Bearer ${BEARER_TOKEN}" -H 'Content-Type:application/json' -H 'Accept:application/json' -d "${http_request_data}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_body=$(get_response_body "${http_response}")
  if [[ -z "${http_body}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 && "${http_return_code}" -ne 202 ]]; then return 1; fi

  echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.name)'
}

function get_disk_state() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd?api-version=2020-12-01"

  local http_response=$(curl -sSi -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_body=$(get_response_body "${http_response}")
  if [[ -z "${http_body}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 ]]; then return 1; fi

  echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.properties.diskState)'
}

function get_asyncoperation_access_sas() {
  local http_endpoint=$1

  local x=0
  local max_retries=6
  local http_response=
  local http_header=
  local http_body=
  local http_return_code=
  local access_sas=
  while [[ ( $x -lt "${max_retries}" ) && ( -z "${access_sas}" ) ]]; do
    if [[ $x > 0 ]]; then sleep 5; fi

    http_response=$(curl -sSi -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" "${http_endpoint}")

    http_header=$(get_response_header "${http_response}")
    if [[ -z "${http_header}" ]]; then return 1; fi

    http_body=$(get_response_body "${http_response}")
    if [[ -z "${http_body}" ]]; then return 1; fi

    http_return_code=$(get_http_return_code "${http_header}")
    if [[ "${http_return_code}" -ne 200 && "${http_return_code}" -ne 202 ]]; then return 1; fi

    access_sas=$(echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.properties.output.accessSAS)')

    x=$(( $x + 1 ))
  done

  echo "${access_sas}"
}

function get_access_sas() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd/beginGetAccess?api-version=2020-12-01"
  local http_request_data='{"access":"Write","durationInSeconds":86400}'

  local http_response=$(curl -sSi -X POST -H "Authorization: Bearer ${BEARER_TOKEN}" -H 'Content-Type:application/json' -H 'Accept:application/json' -d "${http_request_data}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" == 200 ]]; then
    local http_body=$(get_response_body "${http_response}")
    if [[ -z "${http_body}" ]]; then return 1; fi

    local access_sas=$(echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.accessSAS)' )
  elif [[ "${http_return_code}" == 202 ]]; then
    local operation_endpoint=$(get_operation_endpoint "${http_header}")
    local access_sas=$(get_asyncoperation_access_sas "${operation_endpoint}")
  fi

  echo "${access_sas}"
}

function rhcos_disk_copy() {
  "${INSTALLER_WORKSPACE}azcopy" copy "${RHCOS_IMAGE_URL}" "${ACCESS_SAS}" --blob-type PageBlob
}

function revoke_access_sas() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd/endGetAccess?api-version=2020-12-01"

  local http_response=$(curl -sSi -X POST -H "Authorization: Bearer ${BEARER_TOKEN}" -d "" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 && "${http_return_code}" -ne 202 ]]; then return 1; fi
}

max_retries=6

install_deps

BEARER_TOKEN=$(get_bearer_token)
if [[ -z "${BEARER_TOKEN}" ]]; then exit 1; fi

MANAGED_DISK_NAME=$(create_managed_disk)
if [[ -z "${MANAGED_DISK_NAME}" ]]; then exit 1; fi
x=0
MANAGED_DISK_STATE=
while [[ ( $x -lt "${max_retries}" ) && "${MANAGED_DISK_STATE}" != "ReadyToUpload" ]]; do
  if [[ $x > 0 ]]; then sleep 5; fi
  MANAGED_DISK_STATE=$(get_disk_state)
  x=$(( $x + 1 ))
done
if [[ "${MANAGED_DISK_STATE}" != "ReadyToUpload" ]]; then exit 1; fi

ACCESS_SAS=$(get_access_sas)
if [[ -z "${ACCESS_SAS}" ]]; then exit 1; fi 
x=0
ACCESS_DISK_STATE=
while [[ ( $x -lt "${max_retries}" ) && "${ACCESS_DISK_STATE}" != "ActiveUpload" ]]; do
  if [[ $x > 0 ]]; then sleep 5; fi
  ACCESS_DISK_STATE=$(get_disk_state)
  x=$(( $x + 1 ))
done
if [[ "${ACCESS_DISK_STATE}" != "ActiveUpload" ]]; then exit 1; fi

rhcos_disk_copy

revoke_access_sas
x=0
REVOKE_DISK_STATE=
while [[ ( $x -lt "${max_retries}" ) && "${REVOKE_DISK_STATE}" != "Unattached" ]]; do
  if [[ $x > 0 ]]; then sleep 5; fi
  REVOKE_DISK_STATE=$(get_disk_state)
  x=$(( $x + 1 ))
done
if [[ "${REVOKE_DISK_STATE}" != "Unattached" ]]; then exit 1; fi

exit 0