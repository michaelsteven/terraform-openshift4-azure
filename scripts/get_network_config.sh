#!/bin/bash
set -e
set -x

# installer_workspace is passed in the query, cant' use it to execute jq yet
#eval "$(${installer_workspace}jq -r '@sh "installer_workspace=\(.installer_workspace)"')"
STD_IN=$(</dev/stdin)
INSTALLER_WORKSPACE=$(echo ${STD_IN} | grep -oP '"installer_workspace":"\K[^"]+')
eval "$( echo ${STD_IN} | ${INSTALLER_WORKSPACE}jq -r '@sh "SUBSCRIPTION_ID=\(.azure_subscription_id) TENANT_ID=\(.azure_tenent_id) CLIENT_ID=\(.azure_client_id) CLIENT_SECRET=\(.azure_client_secret) RESOURCE_GROUP_NAME_SUBSTRING=\(.azure_resource_group_name_substring) CONTROL_PLANE_SUBNET_SUBSTRING=\(.azure_control_plane_subnet_substring) COMPUTE_SUBNET_SUBSTRING=\(.azure_compute_subnet_substring)"' )"

scripts_dir="$(dirname "$0")"
source "$scripts_dir/api_functions.sh"

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

function get_resource_groups() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourcegroups?api-version=2021-04-01"

  local http_response=$(curl -sSi -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_body=$(get_response_body "${http_response}")
  if [[ -z "${http_body}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 ]]; then return 1; fi

  echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.value)'
}

function get_resource_group_name() {
  local resource_groups=$(get_resource_groups)

  #local resource_group_name=$(echo "${resource_groups}" | ${INSTALLER_WORKSPACE}jq '.[].name' | grep ${RESOURCE_GROUP_NAME_SUBSTRING} | tr -d '"')
  local resource_group_name=$(echo "${resource_groups}" | ${INSTALLER_WORKSPACE}jq -r '.[].name' | grep ${RESOURCE_GROUP_NAME_SUBSTRING})

  echo ${resource_group_name}
}

function get_virtual_networks() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/virtualNetworks?api-version=2021-05-01"

  local http_response=$(curl -sSi -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_body=$(get_response_body "${http_response}")
  if [[ -z "${http_body}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 ]]; then return 1; fi

  echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.value)'
}

function get_virtual_network_name() {
  local virtual_networks=$(get_virtual_networks)

  #local virtual_network_name=$(echo "${virtual_networks}" | ${INSTALLER_WORKSPACE}jq '.[0].name' | tr -d '"')
  local virtual_network_name=$(echo "${virtual_networks}" | ${INSTALLER_WORKSPACE}jq -r '.[0].name')

  echo ${virtual_network_name}
}

function get_virtual_network_cidr() {
  local virtual_networks=$(get_virtual_networks)

  local virtual_network_cidr=$(echo "${virtual_networks}" | ${INSTALLER_WORKSPACE}jq -r '.[0].properties.addressSpace' | ${INSTALLER_WORKSPACE}jq -r '.addressPrefixes')
  local virtual_network_cidr=$(echo "${virtual_network_cidr}" | sed 's/\[//' |  sed 's/\]//' ) # ("${virtual_network_cidr}", "[", "") )
  echo ${virtual_network_cidr}
}

function get_virtual_network_usages() {
  local http_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/virtualNetworks/${VIRTUAL_NETWORK_NAME}/usages?api-version=2021-05-01"

  local http_response=$(curl -sSi -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_body=$(get_response_body "${http_response}")
  if [[ -z "${http_body}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 ]]; then return 1; fi

  echo "${http_body}" | ${INSTALLER_WORKSPACE}jq -r '(.value)'
}

function get_max_subnet_id() {
  local subnet_substring=$1

  local subnet_usage_stats=$(get_virtual_network_usages)

  local subnet_usage_stats_length=$(echo "${subnet_usage_stats}" | ${INSTALLER_WORKSPACE}jq length)

  local x=0
  local current_value=0
  local limit_value=0
  local subnet_id=
  local available_ips=0
  local max_subnet_id=
  local max_available_ips=0

  while [[ $x -lt "${subnet_usage_stats_length}" ]]; do
    current_value=$(echo "${subnet_usage_stats}" | ${INSTALLER_WORKSPACE}jq -r ".[$x].currentValue")
    subnet_id=$(echo "${subnet_usage_stats}" | ${INSTALLER_WORKSPACE}jq -r ".[$x].id")
    limit_value=$(echo "${subnet_usage_stats}" | ${INSTALLER_WORKSPACE}jq -r ".[$x].limit")
    available_ips=$(( $limit_value - $current_value ))
    if [[ "$subnet_id" == *"$subnet_substring"* && (${available_ips} -gt ${max_available_ips} || ${max_available_ips} -le 0) ]]; then
      max_available_ips=${available_ips}
      max_subnet_id=${subnet_id}
    fi
    x=$(( $x + 1 ))
  done

  if [[ $max_available_ips -le 0 ]]; then exit 1; fi

  echo ${max_subnet_id}
}

function get_subnet() {
  local http_endpoint=https://management.azure.com$(get_max_subnet_id $1)?api-version=2021-05-01

  local http_response=$(curl -sSi -X GET -H "Authorization: Bearer ${BEARER_TOKEN}" "${http_endpoint}")

  local http_header=$(get_response_header "${http_response}")
  if [[ -z "${http_header}" ]]; then return 1; fi

  local http_body=$(get_response_body "${http_response}")
  if [[ -z "${http_body}" ]]; then return 1; fi

  local http_return_code=$(get_http_return_code "${http_header}")
  if [[ "${http_return_code}" -ne 200 ]]; then return 1; fi

  echo "${http_body}"
}

BEARER_TOKEN=$(get_bearer_token)
if [[ -z "${BEARER_TOKEN}" ]]; then exit 1; fi

RESOURCE_GROUP_NAME=$(get_resource_group_name)
if [[ -z "${RESOURCE_GROUP_NAME}" ]]; then exit 1; fi

VIRTUAL_NETWORK_NAME=$(get_virtual_network_name)
if [[ -z "${VIRTUAL_NETWORK_NAME}" ]]; then exit 1; fi

VIRTUAL_NETWORK_CIDR=$(get_virtual_network_cidr)
if [[ -z "${VIRTUAL_NETWORK_CIDR}" ]]; then exit 1; fi

CONTROL_PLANE_SUBNET=$(get_subnet "${CONTROL_PLANE_SUBNET_SUBSTRING}")
if [[ -z "${CONTROL_PLANE_SUBNET}" ]]; then exit 1; fi
CONTROL_PLANE_SUBNET_NAME=$(echo "${CONTROL_PLANE_SUBNET}" | ${INSTALLER_WORKSPACE}jq -r '(.name)')
if [[ -z "${CONTROL_PLANE_SUBNET_NAME}" ]]; then exit 1; fi
CONTROL_PLANE_SUBNET_ADDRESS_PREFIX=$(echo "${CONTROL_PLANE_SUBNET}" | ${INSTALLER_WORKSPACE}jq -r '(.properties.addressPrefix)')
if [[ -z "${CONTROL_PLANE_SUBNET_ADDRESS_PREFIX}" ]]; then exit 1; fi

COMPUTE_SUBNET=$(get_subnet "${COMPUTE_SUBNET_SUBSTRING}")
if [[ -z "${COMPUTE_SUBNET}" ]]; then exit 1; fi
COMPUTE_SUBNET_NAME=$(echo "${COMPUTE_SUBNET}" | ${INSTALLER_WORKSPACE}jq -r '(.name)')
if [[ -z "${COMPUTE_SUBNET_NAME}" ]]; then exit 1; fi
COMPUTE_SUBNET_ADDRESS_PREFIX=$(echo "${COMPUTE_SUBNET}" | ${INSTALLER_WORKSPACE}jq -r '(.properties.addressPrefix)')
if [[ -z "${COMPUTE_SUBNET_ADDRESS_PREFIX}" ]]; then exit 1; fi

${INSTALLER_WORKSPACE}jq -n \
  --arg resource_group_name "$RESOURCE_GROUP_NAME" \
  --arg virtual_network "$VIRTUAL_NETWORK_NAME" \
  --arg control_plane_subnet "$CONTROL_PLANE_SUBNET_NAME" \
  --arg control_plane_address_prefix "$CONTROL_PLANE_SUBNET_ADDRESS_PREFIX" \
  --arg compute_subnet "$COMPUTE_SUBNET_NAME" \
  --arg compute_address_prefix "$COMPUTE_SUBNET_ADDRESS_PREFIX" \
  --arg virtual_network_cidr "$VIRTUAL_NETWORK_CIDR" \
  '{"resource_group_name":$resource_group_name, "virtual_network":$virtual_network, "control_plane_subnet":$control_plane_subnet, "control_plane_address_prefix":$control_plane_address_prefix, "compute_subnet":$compute_subnet, "compute_address_prefix":$compute_address_prefix, "virtual_network_cidr":$virtual_network_cidr}'
