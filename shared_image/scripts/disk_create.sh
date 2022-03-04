#!/bin/bash
set -e
if [[ "${BASH_DEBUG}" == "true" || "${TF_LOG}" == "TRACE" || "${TF_LOG}" == "DEBUG" ]]; then set -x; fi

scripts_dir="$(dirname "$0")"
source "$scripts_dir/disk_functions.sh"

max_retries=6

install_deps
if [[ $? -ne 0 ]]; then exit 1; fi

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
if [[ $? -ne 0 ]]; then exit 1; fi

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