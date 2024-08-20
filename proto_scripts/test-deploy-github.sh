#!/bin/bash
source .env.coolify
BEARER="Authorization: Bearer $COOLIFY_API_KEY"

GH_PRIVATE=0

# ------------------------------------------------------------------------------
# SET_SERVER_ENV
# Required: $1 = Key
# Required: $2 = Value
# Optional: $3 = Is Preview?
# ------------------------------------------------------------------------------
set_server_env() {
  if [ -z "$1" ]; then
    echo "ERROR: No 'Key' Provided for Environment Variable!"
    exit 1
  fi
  if [ -z "$2" ]; then
    echo "ERROR: No 'Value' Provided for Environment Variable!"
    exit 1
  fi
  if [ -z "$3" ]; then
    local is_preview="false"
  else
    local is_preview="$3"
  fi
  local env_payload=$(cat <<EOF
{
  "key": "$1",
  "value": "$2",
  "is_preview": $is_preview
}
EOF
)
  local env_return=$(curl -s --request POST \
    --url $COOLIFY_BASE_URL/api/v1/applications/$configured_server_uuid/envs \
    --header "$BEARER" \
    --header 'Content-Type: application/json' \
    -d "$env_payload")
  local env_uuid=$(jq -r ".uuid" <<< "$env_return")
  if [ -z "$env_uuid" ]; then
    echo "ERROR: Server Set Env Variable Failed!"
    if ! (echo "$env_return" | jq . ); then
      echo "$env_return"
    fi
    exit 1
  fi
  return 0
}


# Set Coolify UUIDs
project_uuid="a484kkc"
server_uuid="j484wks"
environment_name="production"
github_app_uuid="zgg8c48"

# Set Github variables
# git_repository="tjr214/wasp-todo-demo-app"
git_repository="https://github.com/tjr214/wasp-todo-demo-app.git"
git_branch="main"
git_commit_sha="HEAD"

# Set Coolify deployment variables
client_ports_exposes="80"
client_build_pack="static"
client_description="This is a cool fucking frontend"
client_domains="$WASP_WEB_CLIENT_URL"
client_base_directory="/deploy/client"
client_instant_deploy="false"

server_ports_exposes="$PORT"
server_build_pack="dockerfile"
server_description="This is a cool fucking Backend"
server_domains="$WASP_SERVER_URL"
server_base_directory="/deploy/server"
server_instant_deploy="false"


# SERVER PAYLOADS
if [ $GH_PRIVATE -eq 0 ]; then
  # Deploying from Public GitHub Repo
  server_payload=$(cat <<EOF
{
  "project_uuid": "$project_uuid",
  "server_uuid": "$server_uuid",
  "environment_name": "$environment_name",
  "git_repository": "$git_repository",
  "git_branch": "$git_branch",
  "git_commit_sha": "$git_commit_sha",
  "ports_exposes": "$server_ports_exposes",
  "build_pack": "$server_build_pack",
  "description": "$server_description",
  "domains": "$server_domains",
  "base_directory": "$server_base_directory",
  "instant_deploy": $server_instant_deploy
}
EOF
)
elif [ $GH_PRIVATE -eq 1 ]; then
  # Deploying from Private GitHub App
  server_payload=$(cat <<EOF
{
  "project_uuid": "$project_uuid",
  "server_uuid": "$server_uuid",
  "environment_name": "$environment_name",
  "github_app_uuid": "$github_app_uuid",
  "git_repository": "$git_repository",
  "git_branch": "$git_branch",
  "git_commit_sha": "$git_commit_sha",
  "ports_exposes": "$server_ports_exposes",
  "build_pack": "$server_build_pack",
  "description": "$server_description",
  "domains": "$server_domains",
  "base_directory": "$server_base_directory",
  "instant_deploy": $server_instant_deploy
}
EOF
)
fi

# CLIENT PAYLOADS
if [ $GH_PRIVATE -eq 0 ]; then
  # Deploying from Public GitHub Repo
  client_payload=$(cat <<EOF
{
  "project_uuid": "$project_uuid",
  "server_uuid": "$server_uuid",
  "environment_name": "$environment_name",
  "git_repository": "$git_repository",
  "git_branch": "$git_branch",
  "git_commit_sha": "$git_commit_sha",
  "ports_exposes": "$client_ports_exposes",
  "build_pack": "$client_build_pack",
  "description": "$client_description",
  "domains": "$client_domains",
  "base_directory": "$client_base_directory",
  "instant_deploy": $client_instant_deploy
}
EOF
)
elif [ $GH_PRIVATE -eq 1 ]; then
  # Deploying from Private GitHub App
  client_payload=$(cat <<EOF
{
  "project_uuid": "$project_uuid",
  "server_uuid": "$server_uuid",
  "environment_name": "$environment_name",
  "github_app_uuid": "$github_app_uuid",
  "git_repository": "$git_repository",
  "git_branch": "$git_branch",
  "git_commit_sha": "$git_commit_sha",
  "ports_exposes": "$client_ports_exposes",
  "build_pack": "$client_build_pack",
  "description": "$client_description",
  "domains": "$client_domains",
  "base_directory": "$client_base_directory",
  "instant_deploy": $client_instant_deploy
}
EOF
)
fi

# Setup the Server on Coolify
if [ $GH_PRIVATE -eq 0 ]; then
  # Deploying from Public GitHub Repo
  coolify_server_return=$(curl -s --request POST \
    --url $COOLIFY_BASE_URL/api/v1/applications/public \
    --header "$BEARER" \
    --header 'Content-Type: application/json' \
    -d "$server_payload")
elif [ $GH_PRIVATE -eq 1 ]; then
  # Deploying from Private GitHub App
  coolify_server_return=$(curl -s --request POST \
    --url $COOLIFY_BASE_URL/api/v1/applications/private-github-app \
    --header "$BEARER" \
    --header 'Content-Type: application/json' \
    -d "$server_payload")
fi
configured_server_uuid=$(jq -r ".uuid" <<< "$coolify_server_return")
if [ -z "$configured_server_uuid" ]; then
  echo "ERROR: Server Deployment Failed!"
  exit 1
else
  echo "SERVER SETUP RETURN:"
  if ! (echo "$coolify_server_return" | jq . ); then
    echo "$coolify_server_return"
  fi
fi

# Config the Server Env Vars
set_server_env "DATABASE_URL" "$DATABASE_URL"
set_server_env "WASP_WEB_CLIENT_URL" "$WASP_WEB_CLIENT_URL"
set_server_env "WASP_SERVER_URL" "$WASP_SERVER_URL"
set_server_env "PORT" "$PORT"
set_server_env "JWT_SECRET" "$JWT_SECRET"

# And again for the Preview Deploys
set_server_env "DATABASE_URL" "$DATABASE_URL" true
set_server_env "WASP_WEB_CLIENT_URL" "$WASP_WEB_CLIENT_URL" true
set_server_env "WASP_SERVER_URL" "$WASP_SERVER_URL" true
set_server_env "PORT" "$PORT" true
set_server_env "JWT_SECRET" "$JWT_SECRET" true

# Actually deploy the Server to Coolify!
deploy_server_return=$(curl -s --request POST \
  --url $COOLIFY_BASE_URL/api/v1/applications/$configured_server_uuid/start \
  --header "$BEARER" \
  --header 'Content-Type: application/json')

echo
echo "DEPLOY SERVER RETURN:"
if ! (echo "$deploy_server_return" | jq . ); then
  echo "$deploy_server_return"
fi

# Next, setup the Client
if [ $GH_PRIVATE -eq 0 ]; then
  # Deploying from Public GitHub Repo
  coolify_client_return=$(curl -s --request POST \
    --url $COOLIFY_BASE_URL/api/v1/applications/public \
    --header "$BEARER" \
    --header 'Content-Type: application/json' \
    -d "$client_payload")
elif [ $GH_PRIVATE -eq 1 ]; then
  # Deploying from Private GitHub App
  coolify_client_return=$(curl -s --request POST \
    --url $COOLIFY_BASE_URL/api/v1/applications/private-github-app \
    --header "$BEARER" \
    --header 'Content-Type: application/json' \
    -d "$client_payload")
fi
echo
configured_client_uuid=$(jq -r ".uuid" <<< "$coolify_client_return")
if [ -z "$configured_client_uuid" ]; then
  echo "ERROR: Client Setup Failed!"
  exit 1
else
  echo "CLIENT SETUP RETURN:"
  if ! (echo "$coolify_client_return" | jq . ); then
    echo "$coolify_client_return"
  fi
fi

# Finally, the actual Client deploy to Coolify...
deploy_client_return=$(curl -s --request POST \
  --url $COOLIFY_BASE_URL/api/v1/applications/$configured_client_uuid/start \
  --header "$BEARER" \
  --header 'Content-Type: application/json')
echo
echo "DEPLOY CLIENT RETURN:"
if ! (echo "$deploy_client_return" | jq . ); then
  echo "$deploy_client_return"
fi
