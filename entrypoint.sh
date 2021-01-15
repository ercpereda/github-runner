#!/bin/sh
registration_url="https://github.com/${GITHUB_OWNER}"
if [ -z "${GITHUB_REPOSITORY}" ]; then
    token_url="https://api.github.com/orgs/${GITHUB_OWNER}/actions/runners/registration-token"
else
    token_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/actions/runners/registration-token"
    registration_url="${registration_url}/${GITHUB_REPOSITORY}"
fi

echo ">>>> Requesting token at '${token_url}'"

if [ "${GITHUB_APP_ID}" ]; then
    jwt_token=$(./jwt.sh RS256 "${GITHUB_APP_ID}" "${GITHUB_APP_PK}")
    installations_url="https://api.github.com/app/installation"
    installation_id=$(curl -s  -H "Authorization: Bearer ${jwt_token}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/app/installations | jq --arg app_id "${GITHUB_APP_ID}" '.[] | select(.app_id | contains($app_id | tonumber)) | .id')
    access_token_url="https://api.github.com/app/installations/${installation_id}/access_tokens"
    GITHUB_PAT=$(curl -sX POST -H "Authorization: Bearer ${jwt_token}" -H "Accept: application/vnd.github.v3+json" ${access_token_url} | jq -r '.token')
fi

payload=$(curl -sX POST -H "Authorization: token ${GITHUB_PAT}" ${token_url})
export RUNNER_TOKEN=$(echo $payload | jq .token --raw-output)

if [ -z "${RUNNER_NAME}" ]; then
    RUNNER_NAME=$(hostname)
fi

./config.sh \
    --name "${RUNNER_NAME}" \
    --token "${RUNNER_TOKEN}" \
    --url "${registration_url}" \
    --work "${RUNNER_WORKDIR}" \
    --labels "${RUNNER_LABELS}" \
    --unattended \
    --replace

remove() {
    payload=$(curl -sX POST -H "Authorization: token ${GITHUB_PAT}" ${token_url%/registration-token}/remove-token)
    export REMOVE_TOKEN=$(echo $payload | jq .token --raw-output)

    ./config.sh remove --unattended --token "${REMOVE_TOKEN}"

    sudo rm -rf $RUNNER_WORKDIR/*
}

trap 'remove; exit 130' INT
trap 'remove; exit 143' TERM

./runsvc.sh "$*" &

wait $!

# sleep 1000000

# curl -i -X POST -H "Authorization: Bearer $token" -H "Accept: application/vnd.github.v3+json" https://api.github.com/app/installations/14083993/access_tokens

# token=$(sign rs256 "95241" "$(cat er-github-actions-runner.2021-01-14.private-key.pem)")
