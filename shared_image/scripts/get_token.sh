#!/bin/bash

set -e

eval "$(./jq -r '@sh "export TENANT_ID=\(.tenant_id) CLIENT_ID=\(.client_id) CLIENT_SECRET=\(.client_secret)"')"

AZURE_ENDPOINT='https://login.microsoftonline.com/'${TENANT_ID}'/oauth2/token?api-version=1.0'
AZURE_DATA='grant_type=client_credentials&client_id='${CLIENT_ID}'&client_secret='${CLIENT_SECRET}'&resource=https%3A%2F%2Fmanagement.azure.com%2F'

AZURE_RESPONSE=$(curl -X POST -H 'Content-Type: application/x-www-form-urlencoded' -d ${AZURE_DATA} ${AZURE_ENDPOINT})
ACCESS_TOKEN=$(echo ${AZURE_RESPONSE} | ./jq -r '(.access_token)' )

RESPONSE_JSON=$(./jq -n --arg access_token "${ACCESS_TOKEN}" '{"access_token":$access_token}')

echo ${RESPONSE_JSON}
