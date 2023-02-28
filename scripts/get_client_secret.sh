#!/bin/bash
set -e

# installer_workspace is passed in the query, cant' use it to execute jq yet
#eval "$(${installer_workspace}jq -r '@sh "installer_workspace=\(.installer_workspace)"')"
installer_workspace=`grep -oP '"installer_workspace":"\K[^"]+' <<< "$(</dev/stdin)"`

# if [[  -f ${INSTALLER_WORKSPACE}jq ]]; then
#   ${installer_workspace}jq -n --arg client_secret "$ARM_CLIENT_SECRET" \
#       '{"client_secret":$client_secret}'
# else
#       echo  {\"client_secret\": \"${ARM_CLIENT_SECRET}\"}
# fi


  if [[ ! -f ${installer_workspace}jq ]]; then
    mkdir -p ${installer_workspace}
    case $(uname -s) in
      Darwin)
        curl -sSL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64 -o ${installer_workspace}jq
        ;;
      Linux)
        curl -SL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o ${installer_workspace}jq
        ;;
      *)
        exit 1;;
    esac
    chmod u+x ${installer_workspace}jq
    ${installer_workspace}jq -n --arg client_secret "$ARM_CLIENT_SECRET" \
       '{"client_secret":$client_secret}'  
  else 
    ${installer_workspace}jq -n --arg client_secret "$ARM_CLIENT_SECRET" \
       '{"client_secret":$client_secret}'  
  fi
