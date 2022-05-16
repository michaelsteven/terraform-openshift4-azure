#!/bin/bash
set -e

# installer_workspace is passed in the query, cant' use it to execute jq yet
#eval "$(${installer_workspace}jq -r '@sh "installer_workspace=\(.installer_workspace)"')"
installer_workspace=`grep -oP '"installer_workspace":"\K[^"]+' <<< "$(</dev/stdin)"`

${installer_workspace}jq -n --arg client_secret "$ARM_CLIENT_SECRET" \
      '{"client_secret":$client_secret}'
