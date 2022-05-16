#!/bin/bash

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
