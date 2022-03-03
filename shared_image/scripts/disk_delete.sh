#!/bin/bash
set -e

scripts_dir="$(dirname "$0")"
source "$scripts_dir/disk_functions.sh"

install_deps
if [[ $? -ne 0 ]]; then exit 1; fi

BEARER_TOKEN=$(get_bearer_token)
if [[ -z "${BEARER_TOKEN}" ]]; then exit 1; fi

delete_managed_disk
if [[ $? -ne 0 ]]; then exit 1; fi

exit 0