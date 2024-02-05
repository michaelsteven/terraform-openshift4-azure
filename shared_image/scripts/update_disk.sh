#!/bin/bash
set -e
if [[ "${BASH_DEBUG}" == "true" || "${TF_LOG}" == "TRACE" || "${TF_LOG}" == "DEBUG" ]]; then set -x; fi

scripts_dir="$(dirname "$0")"
source "$scripts_dir/disk_functions.sh"

BEARER_TOKEN=$(get_bearer_token)
if [[ -z "${BEARER_TOKEN}" ]]; then exit 1; fi

max_retries=6

x=0
DISK_STATE=
while [[ ( $x -lt "${max_retries}" ) && "${DISK_STATE}" != "ActiveUpload" ]]; do
  if [[ $x > 0 ]]; then sleep 5; fi
  DISK_STATE=$(get_disk_state)
  x=$(( $x + 1 ))
done
if [[ "${DISK_STATE}" != "ActiveUpload" ]]; then exit 1; else rhcos_disk_copy; fi


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