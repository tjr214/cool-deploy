#!/bin/bash
source .env.coolify
BEARER="Authorization: Bearer $COOLIFY_API_KEY"

# ------------------------------------------------------------------------------
# SET_SERVER_ENV
# Required: $1 = The JSON payload for the env variable
# ------------------------------------------------------------------------------
set_server_env() {
  if [ -z "$1" ]; then
    echo "ERROR: Server Set Env Variable Failed!"
    exit 1
  fi
  local env_payload="$1"
  local env_return=$(curl -s --request POST \
    --url $COOLIFY_BASE_URL/api/v1/applications/$deployed_server_uuid/envs \
    --header "$BEARER" \
    --header 'Content-Type: application/json' \
    -d "$env_payload")
  local env_uuid=$(jq -r ".uuid" <<< "$env_return")
  if [ -z "$env_uuid" ]; then
    echo "ERROR: Server Set Env Variable Failed!"
    exit 1
  fi
  return 0
}



# Set Coolify UUIDs
project_uuid="a484kkc"
server_uuid="j484wks"
environment_name="production"
# github_app_uuid="zgg8c48"

# Set Github variables
# git_repository="tjr214/wasp-todo-demo-app"
git_repository="https://github.com/tjr214/wasp-todo-demo-app.git"
git_branch="main"
git_commit_sha="HEAD"

# Set Coolify deployment variables
client_ports_exposes="80"
# client_build_pack="nixpacks"
client_build_pack="static"
client_description="This is a cool fucking frontend"
client_domains="$WASP_WEB_CLIENT_URL"
client_base_directory="/"
client_publish_directory="/deploy/client"
client_instant_deploy="true"

server_ports_exposes="$PORT"
server_build_pack="dockerfile"
server_description="This is a cool fucking Backend"
server_domains="$WASP_SERVER_URL"
server_base_directory="/deploy/server"
server_instant_deploy="false"


# # This is NOT working with call to Endpoint; Error is:
# # column "is_static" of relation "applications" does not exist
# is_static="true"

# Server Payloads
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
  "publish_directory": "$server_publish_directory",
  "instant_deploy": $server_instant_deploy
  }
EOF
)

server_db_env_payload=$(cat <<EOF
{
  "key": "DATABASE_URL",
  "value": "$DATABASE_URL",
  "is_preview": false
  }
EOF
)

server_frontend_env_payload=$(cat <<EOF
{
  "key": "WASP_WEB_CLIENT_URL",
  "value": "$WASP_WEB_CLIENT_URL",
  "is_preview": false
  }
EOF
)

server_backend_env_payload=$(cat <<EOF
{
  "key": "WASP_SERVER_URL",
  "value": "$WASP_SERVER_URL",
  "is_preview": false
  }
EOF
)

server_port_env_payload=$(cat <<EOF
{
  "key": "PORT",
  "value": "$PORT",
  "is_preview": false
  }
EOF
)

server_jwt_env_payload=$(cat <<EOF
{
  "key": "JWT_SECRET",
  "value": "$JWT_SECRET",
  "is_preview": false
  }
EOF
)

# Client Payloads
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
  "publish_directory": "$client_publish_directory",
  "instant_deploy": $client_instant_deploy
  }
EOF
)


# Setup the Server
coolify_server_return=$(curl -s --request POST \
  --url $COOLIFY_BASE_URL/api/v1/applications/public \
  --header "$BEARER" \
  --header 'Content-Type: application/json' \
  -d "$server_payload")

deployed_server_uuid=$(jq -r ".uuid" <<< "$coolify_server_return")
if [ -z "$deployed_server_uuid" ]; then
  echo "ERROR: Server Deployment Failed!"
  exit 1
else
  echo "SERVER SETUP RETURN:"
  if ! (echo "$coolify_server_return" | jq . ); then
    echo "$coolify_server_return"
  fi
fi

# Setup the Server Env Vars
set_server_env "$server_db_env_payload"
set_server_env "$server_frontend_env_payload"
set_server_env "$server_backend_env_payload"
set_server_env "$server_port_env_payload"
set_server_env "$server_jwt_env_payload"

# Deploy the Server!
deploy_server_return=$(curl -s --request POST \
  --url $COOLIFY_BASE_URL/api/v1/applications/$deployed_server_uuid/start \
  --header "$BEARER" \
  --header 'Content-Type: application/json')

echo
echo "DEPLOY SERVER RETURN:"
if ! (echo "$deploy_server_return" | jq . ); then
  echo "$deploy_server_return"
fi

# Deploy the Client!
coolify_client_return=$(curl -s --request POST \
  --url $COOLIFY_BASE_URL/api/v1/applications/public \
  --header "$BEARER" \
  --header 'Content-Type: application/json' \
  -d "$client_payload")

echo
echo "CLIENT SETUP & DEPLOY RETURN:"
if ! (echo "$coolify_client_return" | jq . ); then
  echo "$coolify_client_return"
fi
