#!/bin/bash
set -e

function install_deps() {
  if [[ ! -f ${INSTALLER_WORKSPACE}jq ]]; then 
    mkdir -p ${INSTALLER_WORKSPACE}
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
    mkdir -p ${INSTALLER_WORKSPACE}
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

# Description: When curl commands are passed an argument of 'sSi' the response will contain both the HTTP Header and 
#              the HTTP Body seperated by a blank line. The response is split by this blank line and if the split string 
#              contains both a line containing 'HTTP' and a line containing 'Content-Length' it is assumed to be 
#              the HTTP Header and is returned.
#
# Arguments: An HTTP Response string
# Return: A string containing the HTTP Header
#
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

# Description: When curl commands are passed an argument of 'sSi' the response will contain both the HTTP Header and 
#              the HTTP Body seperated by a blank line. For the HTTP Body, it is assumed that it is returned as a JSON
#              string.  The response is split by this blank line and if the split string starts with the '{' character
#              and ends with the '}' character, it is assumed to be the HTTP Body and is returned.
#
# Arguments: An HTTP Response string
# Return: A string containing the HTTP Body
#
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

# Arguments: An HTTP Header string
# Return: The HTTP Return Code
#
function get_http_return_code() {
  echo $1 | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r")' | grep HTTP | xargs | ${INSTALLER_WORKSPACE}jq -R -s 'split(" ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]'
}

# Arguments: An HTTP Header string
# Return: The HTTP Content Length of the HTTP Body
#
function get_content_length() {
  echo $1 | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r")' | grep -i Content-Length | ${INSTALLER_WORKSPACE}jq -R -s 'split(": ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' | tr -d '",'
}

# Arguments: An HTTP Header string
# Return: The URL to retrieve the Azure Async Operation payload
#
function get_operation_endpoint() {
  echo $1 | ${INSTALLER_WORKSPACE}jq -R -s 'split("\r")' | grep -i azure-asyncoperation | ${INSTALLER_WORKSPACE}jq -R -s 'split(": ")' | ${INSTALLER_WORKSPACE}jq -r '.[1]' | tr -d '",'
}

# Arguments: None
# Return: A string containing the Authentication Bearer Token
#
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

# Arguments: None
# Return: None
#
function delete_managed_disk() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd?api-version=2020-12-01"
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

# Arguments: None
# Return: None
#
function rhcos_disk_copy() {
  "${INSTALLER_WORKSPACE}azcopy" copy "${RHCOS_IMAGE_URL}" "${ACCESS_SAS}" --blob-type PageBlob
}

# Arguments: None
# Return: None
#
function revoke_access_sas() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/disks/coreos-${OPENSHIFT_VERSION}-vhd/endGetAccess?api-version=2020-12-01"

  local http_response=$(curl -sSi -X POST -H "Authorization: Bearer ${BEARER_TOKEN}" -d "" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 && "${http_return_code}" -ne 202 ]]; then return 1; fi
}