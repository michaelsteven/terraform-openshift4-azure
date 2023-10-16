#!/bin/bash
set -e

scripts_dir="$(dirname "$0")/../../scripts"
source "$scripts_dir/api_functions.sh"

# Arguments: None
# Return: A string containing the Authentication Bearer Token
#
function get_bearer_token() {
  local http_endpoint="https://login.microsoftonline.com/${TENANT_ID}/oauth2/token?api-version=1.0"
  
  if [[ -z "${CLIENT_SECRET}" ]]; then 
    local http_request_data="grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${ARM_CLIENT_SECRET}&resource=https%3A%2F%2Fmanagement.azure.com%2F"
  else 
    local http_request_data="grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&resource=https%3A%2F%2Fmanagement.azure.com%2F"
  fi  

  local http_response=$(curl -sSi -X POST -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept:application/json' -d "${http_request_data}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_body=$(get_response_body "${http_response}")
  if [[ -z "${http_body}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 ]]; then return 1; fi

  echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.access_token)'
}

# Arguments: URL to a file, in this case the RHCOS VHD to be downloaded
# Return: The size of the disk file in bytes
#
function get_disk_size() {
  local http_endpoint=$1
  local http_response=$(curl -sSI -X GET "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 ]]; then return 1; fi

  echo $(get_content_length "${http_header}")
}

# Arguments: None
# Return: The name of the Azure disk created
#
function create_managed_disk() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-${CLUSTER_ID}-vhd?api-version=2020-12-01"
  
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

# Arguments: None
# Return: None
#
function delete_managed_disk() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-${CLUSTER_ID}-vhd?api-version=2020-12-01"
  local http_request_data=""

  local http_response=$(curl -sSi -X DELETE -H "Authorization: Bearer ${BEARER_TOKEN}" -H 'Content-Type:application/json' -H 'Accept:application/json' -d "${http_request_data}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 && "${http_return_code}" -ne 202 ]]; then return 1; fi
}

# Arguments: None
# Return: The Azure Disk State as the disk is created, granted write access, revoked write access, and 
#         data uploaded to the disk. [ReadyToUpload, ActiveUpload, Unattached]
#
function get_disk_state() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-${CLUSTER_ID}-vhd?api-version=2020-12-01"

  local http_response=$(curl -sSi -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_body=$(get_response_body "${http_response}")
  if [[ -z "${http_body}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 ]]; then return 1; fi

  echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.properties.diskState)'
}

# Arguments: None
# Return: A String containing the Access SAS URL to the disk when the original request is performed
#         asynchronously as determined by Azure.
#
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

# Arguments: None
# Return: A String containing the Access SAS URL to the disk.
#
function get_access_sas() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-${CLUSTER_ID}-vhd/beginGetAccess?api-version=2020-12-01"
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

# Arguments: None
# Return: None
#
function rhcos_disk_copy() {
  if  $PROXY_EVAL; then 
    export no_proxy=.blob.storage.azure.net;
  fi
  "${INSTALLER_WORKSPACE}azcopy" copy "${RHCOS_IMAGE_URL}" "${ACCESS_SAS}" --blob-type PageBlob
}

# Arguments: None
# Return: None
#
function revoke_access_sas() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-${CLUSTER_ID}-vhd/endGetAccess?api-version=2020-12-01"

  local http_response=$(curl -sSi -X POST -H "Authorization: Bearer ${BEARER_TOKEN}" -d "" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 && "${http_return_code}" -ne 202 ]]; then return 1; fi
}