#!/bin/bash
set -e
if [[ "${BASH_DEBUG}" == "true" || "${TF_LOG}" == "TRACE" || "${TF_LOG}" == "DEBUG" ]]; then set -x; fi

scripts_dir="$(dirname "$0")"
source "$scripts_dir/disk_functions.sh"

BEARER_TOKEN=$(get_bearer_token)
if [[ -z "${BEARER_TOKEN}" ]]; then exit 1; fi

delete_managed_disk
if [[ $? -ne 0 ]]; then exit 1; fi

exit 0