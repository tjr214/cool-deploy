#!/bin/bash
source .env.coolify
BEARER="Authorization: Bearer $COOLIFY_API_KEY"

GH_PRIVATE=0

# ------------------------------------------------------------------------------
# Parsing the JSON from Coolify's API requires the `jq` command line tool.
# Make sure it is installed and available on the system.
# ------------------------------------------------------------------------------
detect_jq() {
  if ! command -v jq &> /dev/null; then
    echo -e "\033[1;31mERROR:\033[0m \033[31m\`jq\` is not installed. Please install it using the following commands:\033[0m"
    case "$OSTYPE" in
      darwin*) # macOS
        echo -e "  \033[33mbrew install jq\033[0m"
        ;;
      linux*)
        echo -e "  \033[33msudo apt-get install jq\033[0m (Ubuntu/Debian-based systems)"
        echo -e "  \033[33msudo yum install jq\033[0m (RHEL/CentOS-based systems)"
        echo -e "  \033[33msudo dnf install jq\033[0m (Fedora-based systems)"
        ;;
      *)
        echo -e "Sorry, we don't have installation instructions for your platform."
        echo -e "Please install jq manually by referring to: https://github.com/jqlang/jq"
        ;;
    esac
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# GET_COOLIFY_VERSION
# ------------------------------------------------------------------------------
get_coolify_version() {
  local version=$(curl -s --request GET \
    --url $COOLIFY_BASE_URL/api/v1/version \
    --header "$BEARER")
echo "$version"
}

# ------------------------------------------------------------------------------
# GET_COOLIFY_SERVERS
# Optional: $1 = if already retrieved UUID, check to make sure it is valid.
# ------------------------------------------------------------------------------
get_coolify_servers() {
  if [ ! -z "$1" ]; then # $1 is not empty, get ready to do the check!
    valid_server=0
  fi
  local servers=$(curl -s --request GET \
    --url $COOLIFY_BASE_URL/api/v1/servers \
    --header "$BEARER")

  local server_count=$(jq '. | length' <<< "$servers")
  for ((i = 0; i < server_count; i++)); do # Loop through all servers
    local uuid=$(jq -r ".[$i].uuid" <<< "$servers")
    local description=$(jq -r ".[$i].description" <<< "$servers")
    local name=$(jq -r ".[$i].name" <<< "$servers")
    if [ -z "$1" ]; then
      echo -e "\033[33mServer-$((i+1)):\033[0m \033[1;31m$name\033[0m"
      echo -e "  UUID: \033[1;37m$uuid\033[0m"
      echo -e "  Description: $description"
    else
      if [ "$uuid" == "$1" ]; then
        valid_server=1
      fi
    fi
  done # End of server loop
  if [ ! -z "$1" ]; then
    if [ $valid_server -eq 0 ]; then
      echo -e "\033[1;31mERROR: Server with UUID \`$1\` not found!\033[0m"
      return 1
    fi
    return 0
  fi
  return 0
}

# ------------------------------------------------------------------------------
# GET_COOLIFY_PROJECTS
# Optional: $1 = if already retrieved UUID, check to make sure it is valid.
# ------------------------------------------------------------------------------
get_coolify_projects() {
  if [ ! -z "$1" ]; then
    valid_project=0
  fi
  local projects=$(curl -s --request GET \
    --url $COOLIFY_BASE_URL/api/v1/projects \
    --header "$BEARER")
  local project_count=$(jq '. | length' <<< "$projects")
  for ((i = 0; i < project_count; i++)); do # Loop through all projects
    local uuid=$(jq -r ".[$i].uuid" <<< "$projects")
    if [ -z "$1" ]; then # $1 is empty, just print the data
      local name=$(jq -r ".[$i].name" <<< "$projects")
      # local id=$(jq -r ".[$i].id" <<< "$projects")
      project_info=$(curl -s --request GET \
        --url $COOLIFY_BASE_URL/api/v1/projects/$uuid \
        --header "$BEARER")
      local description=$(jq -r ".description" <<< "$project_info")
      # local created_at=$(jq -r ".created_at" <<< "$project_info")
      # local updated_at=$(jq -r ".updated_at" <<< "$project_info")
      echo -e "\033[33mProject-$((i+1)):\033[0m \033[1;31m$name\033[0m"
      echo -e "  Description: $description"
      echo -e "  UUID: \033[1;37m$uuid\033[0m"
      # echo -e "  ID: $id"
      # echo -e "  Created At: $created_at"
      # echo -e "  Updated At: $updated_at"
    else # Check if the UUID matches the one provided
      if [ "$uuid" == "$1" ]; then
        valid_project=1
      fi
    fi
  done # End of project loop
  if [ ! -z "$1" ]; then
    if [ $valid_project -eq 0 ]; then
      echo -e "\033[1;31mERROR: Project with UUID \`$1\` not found!\033[0m"
      return 1
    fi
    return 0
  fi
  return 0
}

# ------------------------------------------------------------------------------
# NEW_COOLIFY_PROJECT
# ------------------------------------------------------------------------------
new_coolify_project() {
  local project_name="$1"
  local project_description="$2"
  local project_info=$(curl -s --request POST \
    --url $COOLIFY_BASE_URL/api/v1/projects \
    --header "$BEARER" \
    --header 'Content-Type: application/json' \
    --data '{
    "name": "'"$project_name"'",
    "description": "'"$project_description"'"
  }')
  local project_uuid=$(jq -r ".uuid" <<< "$project_info")
  echo "$project_uuid"
}

# ------------------------------------------------------------------------------
# GET_COOLIFY_GITHUB_KEY
# Optional: $1 = if already retrieved UUID, check to make sure it is valid.
# ------------------------------------------------------------------------------
get_coolify_github_key() {
  if [ ! -z "$1" ]; then
    valid_key=0
  fi
  local keys=$(curl -s --request GET \
    --url $COOLIFY_BASE_URL/api/v1/security/keys \
    --header "$BEARER")
  local key_found=0
  local key_count=$(jq '. | length' <<< "$keys")
  for ((i = 0; i < key_count; i++)); do # Loop through all keys
    local key_is_git_related=$(jq -r ".[$i].is_git_related" <<< "$keys")
    if [ "$key_is_git_related" == "true" ]; then
      local key_uuid=$(jq -r ".[$i].uuid" <<< "$keys")
      if [ -z "$1" ]; then # $1 is empty, just print the data
        ((key_found++))
        local key_id=$(jq -r ".[$i].id" <<< "$keys")
        local key_name=$(jq -r ".[$i].name" <<< "$keys")
        local key_description=$(jq -r ".[$i].description" <<< "$keys")
        echo -e "\033[33mGithub App Key-$key_found:\033[0m \033[1;31m$key_name\033[0m"
        echo -e "  Description: $key_description"
        echo -e "  UUID: \033[1;37m$key_uuid\033[0m"
      else # Check if the UUID matches the one provided
        if [ "$key_uuid" == "$1" ]; then
          valid_key=1
        fi
      fi
    fi
  done # End of project loop
  if [ ! -z "$1" ]; then
    if [ $valid_key -eq 0 ]; then
      echo -e "\033[1;31mERROR: Github App Key with UUID \`$1\` not found!\033[0m"
      return 1
    fi
    return 0
  fi
  return 0
}

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


# local colors=(black red green yellow blue magenta cyan white reset)
# local color_codes=(30 31 32 33 34 35 36 37 0)

# local styles=(bold italic underline strikethrough)
# local style_codes=(1 3 4 9)

# local backgrounds=(black red green yellow blue magenta cyan white)
# local background_codes=(40 41 42 43 44 45 46 47)


# Detect if the `jq` command line tool is installed and available
detect_jq


# ------------------------------------------------------------------------------
# CUT #1
# CUT BELOW and PASTE INTO the "Configure our `cool-deploy`` script!" section
# of the main `cool-deploy.sh` script.
# ------------------------------------------------------------------------------

# Get the UUID of the server to deploy to:
if [ -z "$COOLIFY_SERVER_UUID" ]; then
  get_coolify_servers
  while true; do
    read -p $'\033[33mEnter the UUID of the Server to Deploy to:\033[0m ' COOLIFY_SERVER_UUID
    if [ -z "$COOLIFY_SERVER_UUID" ]; then
      echo -e "\033[31mPlease enter a valid UUID!\033[0m"
    else
      get_coolify_servers "$COOLIFY_SERVER_UUID"
      if [ $? -eq 0 ]; then
        break
      fi
    fi
  done
fi

# Now, we need to select the Coolify Project to house the deployments:
if [ -z "$COOLIFY_PROJECT_UUID" ]; then
  while true; do # New/List/Add Loop
    read -p $'\033[33mDeploy to New Project or Add to existing one? \033[31mDefault: New \033[33m[New/List/Add]:\033[0m ' new_list_or_add
    if [ -z "$new_list_or_add" ]; then
      new_list_or_add="NEW"
    fi
    new_list_or_add=$(echo "$new_list_or_add" | tr '[:lower:]' '[:upper:]')
    if [ "$new_list_or_add" == "NEW" ]; then # Create a new Project and get its UUID
      while true; do # Get Project Name loop
        read -p $'\033[33mEnter the Project Name:\033[0m ' new_project_name
        if [ -z "$new_project_name" ]; then
          echo -e "\033[31mPlease enter a valid Project Name!\033[0m"
        else
          break
        fi
      done # End of Project Name loop
      while true; do # Get Project Description loop
        read -p $'\033[33mEnter the Project Description:\033[0m ' new_project_description
        if [ -z "$new_project_description" ]; then
          echo -e "\033[31mPlease enter a valid Project Description!\033[0m"
        else
          break
        fi
      done # End of Project Description loop
      COOLIFY_PROJECT_UUID=$(new_coolify_project "$new_project_name" "$new_project_description")
      break
    elif [ "$new_list_or_add" == "LIST" ]; then
      get_coolify_projects
    elif [ "$new_list_or_add" == "ADD" ]; then
      # Get the UUID of the project:
      get_coolify_projects
      while true; do
        read -p $'\033[33mEnter the UUID of the Project to use:\033[0m ' COOLIFY_PROJECT_UUID
        if [ -z "$COOLIFY_PROJECT_UUID" ]; then
          echo -e "\033[31mPlease enter a valid UUID!\033[0m"
        else
          get_coolify_projects "$COOLIFY_PROJECT_UUID"
          if [ $? -eq 0 ]; then
            break
          fi
        fi
      done
      break
    fi
  done # End of New/List/Add Loop
fi

if [ $GH_PRIVATE -eq 1 ]; then
  # Grab the UUID of the Github App Key, so we can actually deploy:
  if [ -z "$COOLIFY_GITHUB_APP_UUID" ]; then
    get_coolify_github_key
    while true; do # Get Github Key loop
      read -p $'\033[33mEnter the UUID of the Github App Key to use:\033[0m ' COOLIFY_GITHUB_APP_UUID
      if [ -z "$COOLIFY_GITHUB_APP_UUID" ]; then
        echo -e "\033[31mPlease enter a valid UUID!\033[0m"
      else
        get_coolify_github_key "$COOLIFY_GITHUB_APP_UUID"
        if [ $? -eq 0 ]; then
          break
        else
          get_coolify_github_key
        fi
      fi
    done
  fi
fi

# ------------------------------------------------------------------------------
# END CUT #1!
# ------------------------------------------------------------------------------



# Set Coolify UUIDs
# project_uuid="a484kkc"
# server_uuid="j484wks"
# github_app_uuid="zgg8c48"
project_uuid="$COOLIFY_PROJECT_UUID"
server_uuid="$COOLIFY_SERVER_UUID"
environment_name="$COOLIFY_ENVIRONMENT_NAME"
if [ $GH_PRIVATE -eq 1 ]; then
  github_app_uuid="$COOLIFY_GITHUB_APP_UUID"
fi

# Set Github variables
# git_repository="tjr214/wasp-todo-demo-app"
git_repository="https://github.com/tjr214/wasp-todo-demo-app.git"
git_branch="$COOLIFY_GIT_BRANCH"
git_commit_sha="$COOLIFY_GIT_COMMIT_SHA"

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

# Display the data we got from Coolify
COOLIFY_VERSION=$(get_coolify_version)
echo
# echo -e "\033[33mCoolify API Key:\033[0m $COOLIFY_API_KEY"
echo -e "\033[33mCoolify Version:\033[0m $COOLIFY_VERSION"
echo -e "\033[33mProject UUID:\033[0m $project_uuid\033[0m"
echo -e "\033[33mDestination Server:\033[0m $server_uuid\033[0m"
echo -e "\033[33mSource Repository:\033[0m $git_repository:$git_branch ($git_commit_sha)\033[0m"
if [ $GH_PRIVATE -eq 1 ]; then
  echo -e "\033[33mUsing Github App Key:\033[0m $github_app_uuid\033[0m"
fi

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
set_server_env "WASP_WEB_CLIENT_URL" "$WASP_WEB_CLIENT_URL"
set_server_env "WASP_SERVER_URL" "$WASP_SERVER_URL"
set_server_env "PORT" "$PORT"
set_server_env "JWT_SECRET" "$JWT_SECRET"

# And again for the Preview Deploys
set_server_env "WASP_WEB_CLIENT_URL" "$WASP_WEB_CLIENT_URL" true
set_server_env "WASP_SERVER_URL" "$WASP_SERVER_URL" true
set_server_env "PORT" "$PORT" true
set_server_env "JWT_SECRET" "$JWT_SECRET" true

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

# ------------------------------------------------------------------------------
# STOP!
# Time to configure the Development & Production Databases, if the user wants.
# ------------------------------------------------------------------------------

# TODO: Configure the dBs!

set_server_env "DATABASE_URL" "$DATABASE_URL"
set_server_env "DATABASE_URL" "$DATABASE_URL" true

# ------------------------------------------------------------------------------
# STOP!
# At this point, Wasp Project is setup & configured on the Coolify Server.
# The Dev and Prod Databases are also configured & up and running.
# All Env Variables are configured.
# NOW we can Build the project and Push it to Git!
# ------------------------------------------------------------------------------

# TODO: Build the project and Push it to Git!

# ------------------------------------------------------------------------------
# RESUME HERE!
# Now, deploy the Coolify Projects so they are live!
# ------------------------------------------------------------------------------

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

# And finally, the actual Client deploys to Coolify, as well...
deploy_client_return=$(curl -s --request POST \
  --url $COOLIFY_BASE_URL/api/v1/applications/$configured_client_uuid/start \
  --header "$BEARER" \
  --header 'Content-Type: application/json')
echo
echo "DEPLOY CLIENT RETURN:"
if ! (echo "$deploy_client_return" | jq . ); then
  echo "$deploy_client_return"
fi
