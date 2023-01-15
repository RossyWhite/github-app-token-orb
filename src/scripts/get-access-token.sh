#!/bin/bash

# reference: https://docs.github.com/en/developers/apps/building-github-apps/authenticating-with-github-apps#authenticating-as-a-github-app

set -euo pipefail

b64enc() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }

app_id="${APP_ID}"
app_private_key="${APP_PRIVATE_KEY}"
duration_seconds="${DURATION_SECONDS:-300}"

# issued at time, 60 seconds in the past to allow for clock drift
iat=$(($(date +%s) - 60))
exp="$((iat + duration_seconds))"

# create the JWT
signed_content="$(echo -n '{"alg":"RS256","typ":"JWT"}' | b64enc).$(echo -n "{\"iat\":${iat},\"exp\":${exp},\"iss\":${app_id}}" | b64enc)"
sig=$(echo -n "$signed_content" | openssl dgst -binary -sha256 -sign <(printf '%s\n' "$app_private_key") | b64enc)
jwt=$(printf '%s.%s\n' "${signed_content}" "${sig}")

installation_id=$(curl -s \
	-H "Accept: application/vnd.github+json" \
	-H "Authorization: Bearer ${jwt}" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/repos/$ORG/$REPO/installation | jq -r '.id')

access_token=$(curl -s -X POST \
	-H "Authorization: Bearer $jwt" \
	-H "Accept: application/vnd.github+json" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/app/installations/"${installation_id}"/access_tokens | jq -r '.token')

curl -i \
	-H "Authorization: Bearer $access_token" \
	-H "Accept: application/vnd.github+json" \
	-H "X-GitHub-Api-Version: 2022-11-28" \
	https://api.github.com/orgs/$ORG/repos