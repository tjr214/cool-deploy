#!/bin/bash

# Some project variables
WASP_PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PARENT_DIR=$(dirname "$WASP_PROJECT_DIR")
FIRST_TIME_RUN=0
NEED_DB_SETUP=0
NEED_DEV_DB_SETUP=0
BEARER=""
GH_PRIVATE=0
COOLIFY_GITHUB_APP_UUID=0
COOLIFY_GIT_COMMIT_SHA="HEAD"

# Deploy directories
DEPLOY_DIR=$WASP_PROJECT_DIR/deploy
CLIENT_DEPLOY_DIR=$DEPLOY_DIR/client
SERVER_DEPLOY_DIR=$DEPLOY_DIR/server

# Get the app name and version of the Wasp App
cd $WASP_PROJECT_DIR
WASP_APP_NAME=$(grep -o 'app \w\+' main.wasp | cut -d' ' -f2)
WASP_VERSION=$(awk '/wasp: {/,/}/ {if ($1 == "version:") {gsub(/[",]/, "", $2); sub(/^\^/, "", $2); print $2; exit}}' main.wasp)
if [ -z "$WASP_APP_NAME" ]; then
  WASP_APP_NAME="unknownWaspApp"
fi
if [ -z "$WASP_VERSION" ]; then
  WASP_VERSION="unknownVersion"
fi


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

# ------------------------------------------------------------------------------
# configure_some_coolify_settings
# TODO
# ------------------------------------------------------------------------------
configure_some_coolify_settings() {
  echo
  local do_header=0
  if [ -z "$COOLIFY_SERVER_UUID" ]; then
    do_header=1
  fi
  if [ -z "$COOLIFY_PROJECT_UUID" ]; then
    do_header=1
  fi
  if [ $GH_PRIVATE -eq 1 ]; then
    if [ -z "$COOLIFY_GITHUB_APP_UUID" ]; then
      do_header=1
    fi
  fi
  if [ -z "$COOLIFY_GIT_REPOSITORY" ]; then
    do_header=1
  fi
  if [ -z "$COOLIFY_GIT_BRANCH" ]; then
    do_header=1
  fi
  if [ -z "$COOLIFY_CLIENT_DESCRIPTION" ]; then
    do_header=1
  fi
  if [ -z "$COOLIFY_SERVER_DESCRIPTION" ]; then
    do_header=1
  fi
  if [ -z "$COOLIFY_GIT_COMMIT_SHA" ]; then
    COOLIFY_GIT_COMMIT_SHA="HEAD"
  fi
  if [ -z "$COOLIFY_ENVIRONMENT_NAME" ]; then
    COOLIFY_ENVIRONMENT_NAME="production"
  fi

  if [ $do_header -eq 1 ]; then
    echo -e "\033[1;32m🤖 --- CONFIGURING SOME COOLIFY SETTINGS & VARIABLES... ---\033[0m"
    echo
  fi

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

  # Let's get the Git repository...
  if [ -z "$COOLIFY_GIT_REPOSITORY" ]; then
    while true; do
      if [ $GH_PRIVATE -eq 1 ]; then
        read -p $'\033[33mEnter the Github App Repository (e.g. username/my-wasp-project):\033[0m ' COOLIFY_GIT_REPOSITORY
      else
        read -p $'\033[33mEnter the Git Repository URL (e.g. https://github.com/username/my-wasp-project):\033[0m ' COOLIFY_GIT_REPOSITORY
      fi
      if [ -z "$COOLIFY_GIT_REPOSITORY" ]; then
        echo -e "\033[31mPlease enter a valid Git Repository URL!\033[0m"
      else
        break
      fi
    done
  fi  

  # ...and its branch
  if [ -z "$COOLIFY_GIT_BRANCH" ]; then
    while true; do
      read -p $'\033[33mEnter the Git Branch (Default: main):\033[0m ' COOLIFY_GIT_BRANCH
      if [ -z "$COOLIFY_GIT_BRANCH" ]; then
        COOLIFY_GIT_BRANCH="main"
        break
      else
        break
      fi
    done
  fi

  # Frontend Description for the Coolify UI
  if [ -z "$COOLIFY_CLIENT_DESCRIPTION" ]; then
    while true; do
      read -p $'\033[33mEnter a Client App description for the Coolify UI (Default: "Wasp Frontend"):\033[0m ' COOLIFY_CLIENT_DESCRIPTION
      if [ -z "$COOLIFY_CLIENT_DESCRIPTION" ]; then
        COOLIFY_CLIENT_DESCRIPTION="Wasp Frontend"
        break
      else
        break
      fi
    done
  fi

  # Backend Description for the Coolify UI
  if [ -z "$COOLIFY_SERVER_DESCRIPTION" ]; then
    while true; do
      read -p $'\033[33mEnter a Server App description for the Coolify UI (Default: "Wasp Backend"):\033[0m ' COOLIFY_SERVER_DESCRIPTION
      if [ -z "$COOLIFY_SERVER_DESCRIPTION" ]; then
        COOLIFY_SERVER_DESCRIPTION="Wasp Backend"
        break
      else
        break
      fi
    done
  fi
  return 0
}

# ------------------------------------------------------------------------------
# run_coolify_healthcheck
# Let's make sure Coolify is up and running!
# ------------------------------------------------------------------------------
run_coolify_healthcheck() {
  local test_call=$(get_coolify_version)
  if [ -z "$test_call" ]; then
    test_call="\033[1;41m FAILED \033[0m"
  else
    test_call="\033[1;42m SUCCESS \033[0m"
  fi
  echo
  echo -e "\033[1;37mCoolify Healthcheck:\033[0m $test_call"

  if [ "$test_call" == "\033[1;41m FAILED \033[0m" ]; then
    echo -e "\033[1;37mOh, no! Something went wrong and we couldn't connect to Coolify!\033[0m"
    echo
    echo -e "\033[1;31m🛑 --- ERROR: 'COOLIFY_BASE_URL' and/or 'COOLIFY_API_KEY' not correctly configured! ---\033[0m"
    echo
    echo -e "COOLIFY_BASE_URL: $COOLIFY_BASE_URL"
    echo -e "COOLIFY_API_KEY: $COOLIFY_API_KEY"
    echo
    exit 1
  elif [ "$test_call" == "\033[1;42m SUCCESS \033[0m" ]; then
    echo -e "\033[1;37mIf you can see this, we can successfully connect to Coolify!\033[0m"
  fi
}

# ------------------------------------------------------------------------------
# CREATE PROJECTS AND DEPLOY DBS
# ------------------------------------------------------------------------------
create_projects_and_deploy_dbs() {
  # DEFINE SERVER PAYLOADS
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

  # DEFINE CLIENT PAYLOADS
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

  # Check if we need to setup a dB
  if [ $NEED_DB_SETUP -eq 1 ]; then
    # Production db payload
    create_prod_db_payload=$(cat <<EOF
{
  "server_uuid": "$server_uuid",
  "project_uuid": "$project_uuid",
  "environment_name": "$environment_name",
  "description": "Production dB",
  "is_public": false,
  "instant_deploy": true
}
EOF
)
  fi

  # Similarly, do we need a dev dB?
  if [ $NEED_DEV_DB_SETUP -eq 1 ]; then
    # Development db payload
    create_dev_db_payload=$(cat <<EOF
{
  "server_uuid": "$server_uuid",
  "project_uuid": "$project_uuid",
  "environment_name": "$environment_name",
  "description": "Development dB",
  "is_public": true,
  "public_port": $dev_db_port,
  "instant_deploy": true
}
EOF
)
  fi

  echo -e "\033[1;32m🤖 --- SETTING UP & CONFIGURING COOLIFY APPS for FRONTEND and BACKEND... ---\033[0m"
  echo

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
  possible_server_error=$(jq -r ".error" <<< "$coolify_server_return")
  possible_server_msg=$(jq -r ".message" <<< "$coolify_server_return")
  possible_server_uuid=$(jq -r ".uuid" <<< "$coolify_server_return")
  if [ ! "$possible_server_error" == "null" ]; then
    echo -e "$server_payload"
    echo
    echo -e "$possible_server_error"
    echo -e "$possible_server_msg"
    echo
    echo -e "\033[1;31m💀 --- COOLIFY ERROR: Backend App Setup Failed! See above for possible details... ---\033[0m"
    echo
    exit 1
  else
    if [ "$possible_server_uuid" == "null" ]; then # If the UUID is null, we can assume the setup failed
      echo -e "$coolify_server_return" # May not even be JSON, print it out
      echo
      echo -e "\033[1;31m💀 --- COOLIFY ERROR: Could not create new Server App! See above for possible details... ---\033[0m"
      echo
      exit 1
    else # If we got here, we can assume a successful setup
      echo -e "- SERVER UUID: $possible_server_uuid"
      echo
      echo -e "\033[33m✅ --- New SERVER App Successfully Created on Coolify! ---\033[0m"
      echo
    fi
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
  configured_client_uuid=$(jq -r ".uuid" <<< "$coolify_client_return")
  possible_client_error=$(jq -r ".error" <<< "$coolify_client_return")
  possible_client_message=$(jq -r ".message" <<< "$coolify_client_return")
  possible_client_uuid=$(jq -r ".uuid" <<< "$coolify_client_return")
  if [ ! "$possible_client_error" == "null" ]; then
    echo -e "$client_payload"
    echo
    echo -e "$possible_client_error"
    echo -e "$possible_client_message"
    echo
    echo -e "\033[1;31m💀 --- COOLIFY ERROR: Frontend App Setup Failed! See above for possible details... ---\033[0m"
    echo
    exit 1
  else
    if [ "$possible_client_uuid" == "null" ]; then # If the UUID is null, we can assume the setup failed
      echo -e "$coolify_client_return" # May not even be JSON, print it out
      echo
      echo -e "\033[1;31m💀 --- COOLIFY ERROR: Could not create new Client App! See above for possible details... ---\033[0m"
      echo
      exit 1
    else
      echo -e "- CLIENT UUID: $possible_client_uuid"
      echo
      echo -e "\033[33m✅ --- New CLIENT App Successfully Created on Coolify! ---\033[0m"
      echo
    fi
  fi

  db_header=0
  if [ $NEED_DB_SETUP -eq 1 ]; then
    db_header=1
  fi
  if [ $NEED_DEV_DB_SETUP -eq 1 ]; then
    db_header=1
  fi

  if [ $db_header -eq 1 ]; then
    echo -e "\033[1;32m🤖 --- DEPLOYING ANY DATABASES REQUIRED ON COOLIFY... ---\033[0m"
    echo
  fi

  # Create the Production Database and bring it online
  if [ $NEED_DB_SETUP -eq 1 ]; then
    create_prod_db_return=$(curl -s --request POST \
      --url $COOLIFY_BASE_URL/api/v1/databases/postgresql \
      --header "$BEARER" \
      --header 'Content-Type: application/json' \
      -d "$create_prod_db_payload")
    possible_prod_db_uuid=$(jq -r ".uuid" <<< "$create_prod_db_return")
    if [ "$possible_prod_db_uuid" == "null" ]; then # If the UUID is null, we can assume the setup failed
      echo -e "$create_prod_db_return" # May not even be JSON, print it out
      echo
      echo -e "\033[1;31m💀 --- COOLIFY ERROR: Production Database Setup Failed! ---\033[0m"
      echo
      exit 1
    else
      prod_db_url=$(jq -r ".internal_db_url" <<< "$create_prod_db_return")
      WASP_DATABASE_URL="$prod_db_url"
      echo -e "- PROD DB UUID: $possible_prod_db_uuid"
      echo -e "- PROD DB URL: $WASP_DATABASE_URL"
      echo
      echo -e "\033[33m✅ --- Production Database Created and Online! ---\033[0m"
      echo
    fi
  fi

  # Create the Development Database and get it up and running
  if [ $NEED_DEV_DB_SETUP -eq 1 ]; then
    create_dev_db_return=$(curl -s --request POST \
      --url $COOLIFY_BASE_URL/api/v1/databases/postgresql \
      --header "$BEARER" \
      --header 'Content-Type: application/json' \
      -d "$create_dev_db_payload")
    possible_dev_db_uuid=$(jq -r ".uuid" <<< "$create_dev_db_return")
    if [ "$possible_dev_db_uuid" == "null" ]; then # If the UUID is null, we can assume the setup failed
      echo -e "$create_dev_db_return" # May not even be JSON, print it out
      echo
      echo -e "\033[1;31m💀 --- COOLIFY ERROR: Development Database Setup Failed! ---\033[0m"
      echo
      exit 1
    else
      dev_db_url=$(jq -r ".external_db_url" <<< "$create_dev_db_return")
      DEV_DATABASE_URL="$dev_db_url"
      echo -e "- DEV DB UUID: $possible_dev_db_uuid"
      echo -e "- DEV DB URL: $DEV_DATABASE_URL"
      echo
      echo -e "\033[33m✅ --- Development Database Created and Online! ---\033[0m"
      echo
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

  # Set the server env vars for the Production db
  DATABASE_URL="$WASP_DATABASE_URL"
  set_server_env "DATABASE_URL" "$DATABASE_URL"
  set_server_env "DATABASE_URL" "$DATABASE_URL" true
  
  echo -e "\033[33m✅ --- Successfully configured ENV Variables for the Server App! ---\033[0m"
  echo
  return 0
}

# ------------------------------------------------------------------------------
# SET PAYLOAD VALUES FOR SERVER & CLIENT
# ------------------------------------------------------------------------------
set_payload_values_for_server_client() {
  project_uuid="$COOLIFY_PROJECT_UUID"
  server_uuid="$COOLIFY_SERVER_UUID"
  COOLIFY_ENVIRONMENT_NAME=${COOLIFY_ENVIRONMENT_NAME:-"production"}
  environment_name="$COOLIFY_ENVIRONMENT_NAME"
  if [ $GH_PRIVATE -eq 1 ]; then
    github_app_uuid="$COOLIFY_GITHUB_APP_UUID"
  fi

  # Set Github variables
  git_repository="$COOLIFY_GIT_REPOSITORY"
  git_branch="$COOLIFY_GIT_BRANCH"
  git_commit_sha="$COOLIFY_GIT_COMMIT_SHA"

  # Set client deployment variables
  client_ports_exposes="80"
  client_build_pack="static"
  client_description="$COOLIFY_CLIENT_DESCRIPTION"
  client_domains="$WASP_WEB_CLIENT_URL"
  client_base_directory="/deploy/client"
  client_instant_deploy="false"

  # And for the server, too
  server_ports_exposes="$PORT"
  server_build_pack="dockerfile"
  server_description="$COOLIFY_SERVER_DESCRIPTION"
  server_domains="$REACT_APP_API_URL"
  server_base_directory="/deploy/server"
  server_instant_deploy="false"
}

# Detect if the `jq` command line tool is installed and available
detect_jq

# ------------------------------------------------------------------------------
# SETUP FILESYSTEM & CONFIGURE DEPLOYMENT VARIABLES
# ------------------------------------------------------------------------------
cd $WASP_PROJECT_DIR

# Lets make sure we have the directories we need
if [ ! -d "$DEPLOY_DIR" ]; then
  echo
  echo -e "\033[1;32m🤖 --- CREATING & SETTING UP DEPLOYMENT DIRECTORIES FOR CLIENT & SERVER... ---\033[0m"
  echo
  mkdir -p "$DEPLOY_DIR"
fi

cd $WASP_PROJECT_DIR
if [ ! -d "$CLIENT_DEPLOY_DIR" ]; then # Does the client dir exist?
  mkdir -p "$CLIENT_DEPLOY_DIR"
  
  # Create README for Client
  cd $CLIENT_DEPLOY_DIR
  if (touch README.md && echo "# Client Build

This \`README.md\` is automatically generated by the Cool-Deploy setup script. It will be updated every time you run \`cool-deploy.sh\`. Please do not edit it manually.

## Deployment Log
" > README.md); then
    echo "- Client Deploy Directory and README.md Created"
  else
    echo "- Client README.md Creation Failed"
    exit 1
  fi
  echo
  echo -e "\033[33m✅ --- Created and populated $CLIENT_DEPLOY_DIR directory. ---\033[0m"
  echo
fi # End of Client deploy dir check

cd $WASP_PROJECT_DIR
if [ ! -d "$SERVER_DEPLOY_DIR" ]; then # Does the server dir exist?
  mkdir -p "$SERVER_DEPLOY_DIR"

  # Create README for Server
  cd $SERVER_DEPLOY_DIR
  if (touch README.md && echo "# Server Build

This \`README.md\` is automatically generated by the Cool-Deploy setup script. It will be updated every time you run \`cool-deploy.sh\`. Please do not edit it manually.

## Deployment Log
" > README.md); then
    echo "- Server Deploy Directory and README.md Created"
  else
    echo "- Server README.md Creation Failed"
    exit 1
  fi
  echo
  echo -e "\033[33m✅ --- Created and populated $SERVER_DEPLOY_DIR directory. ---\033[0m"
  echo
fi # End of Server deploy dir check

cd $WASP_PROJECT_DIR
echo

# Load or Configure the Coolify Environment file
if [ -e ".env.coolify" ]; then
  # Load our Coolify config variables
  FIRST_TIME_RUN=0
  echo -e "\033[1;32m🤖 --- LOADING ENVIRONMENT VARIABLES FROM .env.coolify ---\033[0m"
  source .env.coolify
  if [ -z "$COOLIFY_API_KEY" ]; then
    echo
    echo -e "\033[1;31m🛑 --- ERROR: 'COOLIFY_API_KEY' not found in \`.env.coolify\`! ---\033[0m"
    echo
    exit 1
  fi
  if [ -z "$COOLIFY_BASE_URL" ]; then
    echo
    echo -e "\033[1;31m🛑 --- ERROR: 'COOLIFY_BASE_URL' not found in \`.env.coolify\`! ---\033[0m"
    echo
    exit 1
  fi
  BEARER="Authorization: Bearer $COOLIFY_API_KEY"
  run_coolify_healthcheck
  configure_some_coolify_settings # if any of this is missing, go grab it from the user
else # Configure our `cool-deploy`` script!
  echo -e "\033[1;32m🤖 --- LET'S GET COOL-DEPLOY SET UP! ---\033[0m"
  SETTINGS_CONFIRM=0
  FIRST_TIME_RUN=1
  FINISHED_COOLIFY_SETUP=0
  echo

  # Get the Coolify Base URL
  if [ -z "$COOLIFY_BASE_URL" ]; then
    while true; do
      read -p $'\033[33mEnter your Coolify Base URL (e.g. https://coolify.server.com):\033[0m ' COOLIFY_BASE_URL
      if [ -z "$COOLIFY_BASE_URL" ]; then
        echo -e "\033[31mPlease enter a valid Coolify Base URL!\033[0m"
      else
        break
      fi
    done
  else
    echo -e "\033[33mCoolify Base URL found in ENV: \033[1;34m$COOLIFY_BASE_URL\033[0m"
  fi

  # Get the Coolify API Key
  if [ -z "$COOLIFY_API_KEY" ]; then
    while true; do
      read -p $'\033[33mEnter your Coolify API Key:\033[0m ' COOLIFY_API_KEY
      if [ -z "$COOLIFY_API_KEY" ]; then
        echo -e "\033[31mPlease enter a valid Coolify API Key!\033[0m"
      else
        break
      fi
    done
  else
    echo -e "\033[33mCoolify API Key found in ENV: \033[1;34m$COOLIFY_API_KEY\033[0m"
  fi
  BEARER="Authorization: Bearer $COOLIFY_API_KEY"

  # Run a healthcheck to make sure Coolify is up and running
  run_coolify_healthcheck
  
  while [ $SETTINGS_CONFIRM -eq 0 ]; do # Get user inout and configure vars
    # Configure the Coolify stuff
    configure_some_coolify_settings
    echo

    # Ask the user if they want to setup a dB
    while true; do
      read -p $'\033[33mWould you like to deploy a Production dB on Coolify? [y/n]:\033[0m ' setup_dbs
      if [ "$setup_dbs" == "y" ]; then
        NEED_DB_SETUP=1
        break
      elif [ "$setup_dbs" == "Y" ]; then
        NEED_DB_SETUP=1
        break
      elif [ "$setup_dbs" == "yes" ]; then
        NEED_DB_SETUP=1
        break
      elif [ "$setup_dbs" == "n" ]; then
        NEED_DB_SETUP=0
        break
      elif [ "$setup_dbs" == "N" ]; then
        NEED_DB_SETUP=0
        break
      elif [ "$setup_dbs" == "no" ]; then
        NEED_DB_SETUP=0
        break
      fi
    done
    
    # Now ask the user if they want to setup a development dB
    while true; do
      read -p $'\033[33mWill you be needing a Development dB deployed on Coolify? [y/n]:\033[0m ' setup_dev_dbs
      if [ "$setup_dev_dbs" == "y" ]; then
        NEED_DEV_DB_SETUP=1
        break
      elif [ "$setup_dev_dbs" == "Y" ]; then
        NEED_DEV_DB_SETUP=1
        break
      elif [ "$setup_dev_dbs" == "yes" ]; then
        NEED_DEV_DB_SETUP=1
        break
      elif [ "$setup_dev_dbs" == "N" ]; then
        NEED_DEV_DB_SETUP=0
        break
      elif [ "$setup_dev_dbs" == "n" ]; then
        NEED_DEV_DB_SETUP=0
        break
      elif [ "$setup_dev_dbs" == "no" ]; then
        NEED_DEV_DB_SETUP=0
        break
      fi
    done
    if [ $NEED_DEV_DB_SETUP -eq 1 ]; then
      while true; do
        read -p $'\033[33mWhat port should the Development Database run on? (default 7766):\033[0m ' dev_db_port
        if [ -z "$dev_db_port" ]; then
          dev_db_port=7766
          break
        else
          break
        fi
      done
    fi
    echo
    
    # Get user input for the remaining variables:
    while true; do
      read -p $'\033[33mWhere will the frontend be deployed (ex: https://app.server.com):\033[0m ' WASP_WEB_CLIENT_URL
      if [ -z "$WASP_WEB_CLIENT_URL" ]; then
        echo -e "\033[31mPlease enter a valid FQDN!\033[0m"
      else
        break
      fi
    done

    while true; do
      read -p $'\033[33mWhere will the server be deployed (ex: https://backend.app.server.com):\033[0m ' WASP_SERVER_URL
      if [ -z "$WASP_SERVER_URL" ]; then
        echo -e "\033[31mPlease enter a valid FQDN!\033[0m"
      else
        break
      fi
    done

    read -p $'\033[33mWhat port should the server run on? (default 3000):\033[0m ' WASP_SERVER_PORT
    read -p $'\033[33mJWT Secret Key (or, hit enter to generate):\033[0m ' WASP_JWT_SECRET

    if [ $NEED_DB_SETUP -eq 1 ]; then
      echo -e "\033[1;33mDatabase URI will be configured after Production dB is deployed on Coolify\033[0m "
    else
      while true; do
        read -p $'\033[33mProduction Database URI:\033[0m ' WASP_DATABASE_URL
        if [ -z "$WASP_DATABASE_URL" ]; then
          echo -e "\033[31mPlease enter a valid Database URI!\033[0m"
        else
          break
        fi
      done
    fi # End of getting the Database URI
    
    # Finalize the variables' content
    REACT_APP_API_URL=$WASP_SERVER_URL
    WASP_SERVER_PORT=${WASP_SERVER_PORT:-3000}
    WASP_JWT_SECRET=${WASP_JWT_SECRET:-$(openssl rand -hex 32)}
    WASP_DATABASE_URL=${WASP_DATABASE_URL:-0}

    # Print variables and confirm selections
    echo
    echo -e "\033[1;36m🤖 --- SETTINGS AND ENVIRONMENT CONFIGURATION ---\033[0m"
    echo
    echo -e "\033[1;34mCOOLIFY_API_KEY\033[0m=$COOLIFY_API_KEY"
    echo -e "\033[1;34mCOOLIFY_BASE_URL\033[0m=$COOLIFY_BASE_URL"
    echo -e "\033[1;34mCOOLIFY_SERVER_UUID\033[0m=$COOLIFY_SERVER_UUID"
    echo -e "\033[1;34mCOOLIFY_PROJECT_UUID\033[0m=$COOLIFY_PROJECT_UUID"
    echo -e "\033[1;34mCOOLIFY_GIT_REPOSITORY\033[0m=$COOLIFY_GIT_REPOSITORY"
    echo -e "\033[1;34mCOOLIFY_GIT_BRANCH\033[0m=$COOLIFY_GIT_BRANCH"
    echo -e "\033[1;34mCOOLIFY_GIT_COMMIT_SHA\033[0m=$COOLIFY_GIT_COMMIT_SHA"
    echo
    echo -e "\033[1;34mWASP_WEB_CLIENT_URL\033[0m=$WASP_WEB_CLIENT_URL"
    echo -e "\033[1;34mWASP_SERVER_URL\033[0m=$REACT_APP_API_URL"
    echo -e "\033[1;34mWASP_SERVER_PORT\033[0m=$WASP_SERVER_PORT"
    if [ $NEED_DB_SETUP -eq 0 ]; then
      echo -e "\033[1;34mDATABASE_URL\033[0m=$WASP_DATABASE_URL"
    else
      echo -e "\033[1;34mDATABASE_URL\033[0m=[TBD after dB deployment]"
    fi
    echo -e "\033[1;34mJWT_SECRET\033[0m=$WASP_JWT_SECRET"
    echo
    echo -e "\033[1;34mCLIENT_DEPLOY_DIR\033[0m=$CLIENT_DEPLOY_DIR"
    echo -e "\033[1;34mSERVER_DEPLOY_DIR\033[0m=$SERVER_DEPLOY_DIR"
    echo

    while true; do
      read -p $'\033[31mCONFIRM:\033[33m Would you like to continue with these settings? [y/n]:\033[0m ' CONTINUE
      if [ "$CONTINUE" == "y" ]; then
        SETTINGS_CONFIRM=1
        break
      elif [ "$CONTINUE" == "Y" ]; then
        SETTINGS_CONFIRM=1
        break
      elif [ "$CONTINUE" == "yes" ]; then
        SETTINGS_CONFIRM=1
        break
      elif [ "$CONTINUE" == "n" ]; then
        SETTINGS_CONFIRM=0
        break
      elif [ "$CONTINUE" == "N" ]; then
        SETTINGS_CONFIRM=0
        break
      elif [ "$CONTINUE" == "no" ]; then
        SETTINGS_CONFIRM=0
        break
      fi
    done
    if [ $SETTINGS_CONFIRM -eq 0 ]; then
      echo
      echo -e "\033[31m🛑 --- Settings not configured! Trying again... ---\033[0m"
      COOLIFY_PROJECT_UUID=""
      COOLIFY_SERVER_UUID=""
      COOLIFY_SERVER_DESCRIPTION=""
      COOLIFY_CLIENT_DESCRIPTION=""
      COOLIFY_GIT_REPOSITORY=""
      COOLIFY_GIT_BRANCH=""
      COOLIFY_GIT_COMMIT_SHA="HEAD"
      NEED_DB_SETUP=0
      NEED_DEV_DB_SETUP=0
      dev_db_port=0
      if [ $GH_PRIVATE -eq 1 ]; then
        COOLIFY_GITHUB_APP_UUID=0
      fi
    fi
  done # End of settings config loop

  echo
  echo -e "\033[33m✅ --- Configured settings for \`cool-deploy.sh\`! ---\033[0m"
  echo

  cd $WASP_PROJECT_DIR

  PORT=$WASP_SERVER_PORT
  JWT_SECRET=$WASP_JWT_SECRET
  set_payload_values_for_server_client
  create_projects_and_deploy_dbs

  cd $WASP_PROJECT_DIR

  echo -e "\033[1;32m🤖 --- SAVING CONFIGURATION AND SETTINGS... ---\033[0m"
  echo

  # Create .env.coolify file template
  if (echo "# Frontend URL (Note: this cannot be changed without rerunning \`./cool-deploy.sh\`!)
WASP_WEB_CLIENT_URL={{FRONT_URL}}

# Backend Server
WASP_SERVER_URL={{BACK_URL}}
PORT={{BACK_PORT}}

# Database URL
DATABASE_URL={{DATABASE_URL}}

# JWT Secret for Wasp's Auth System
JWT_SECRET={{AUTH_SECRET}}

# Coolify Platform Settings
COOLIFY_API_KEY={{COOL_KEY}}
COOLIFY_BASE_URL={{COOL_URL}}

# Server and Project UUIDs for the Wasp App
COOLIFY_SERVER_UUID={{COOL_SERVER_UUID}}
COOLIFY_PROJECT_UUID={{COOL_PROJECT_UUID}}
COOLIFY_ENVIRONMENT_NAME={{COOL_ENVIRONMENT_NAME}}

# Coolify Git Config
GH_PRIVATE={{COOL_GIT_PRIVATE}}
COOLIFY_GITHUB_APP_UUID={{COOL_GITHUB_APP_UUID}}
COOLIFY_GIT_REPOSITORY={{COOL_GIT_REPO}}
COOLIFY_GIT_BRANCH={{COOL_GIT_BRANCH}}
COOLIFY_GIT_COMMIT_SHA=\"HEAD\"

# Descriptions for the Frontend/Backend in the Coolify UI
COOLIFY_CLIENT_DESCRIPTION={{COOL_CLIENT_DESCRIPTION}}
COOLIFY_SERVER_DESCRIPTION={{COOL_SERVER_DESCRIPTION}}

FINISHED_COOLIFY_SETUP=0" > .env.coolify); then
    echo -e "\033[33m✅ --- Successfully created Coolify Environment Template file ---\033[0m"
    echo
  else
    echo
    echo -e "\033[31m🛑 --- Failed to create \`.env.coolify\`! See above for possible errors... ---\033[0m"
    echo
    exit 1
  fi

  # Correctly format the literals for the `sed` command
  COOLIFY_COOL_KEY=\"$COOLIFY_API_KEY\"
  COOL_ENVIRONMENT_NAME=\"$COOLIFY_ENVIRONMENT_NAME\"
  COOL_SERVER_DESCRIPTION=\"$COOLIFY_SERVER_DESCRIPTION\"
  COOL_CLIENT_DESCRIPTION=\"$COOLIFY_CLIENT_DESCRIPTION\"

  # Replace the Env placeholders in `.coolify.env`
  if (sed -i "" "s|{{FRONT_URL}}|$WASP_WEB_CLIENT_URL|g; s|{{BACK_URL}}|$REACT_APP_API_URL|g; s|{{BACK_PORT}}|$WASP_SERVER_PORT|g; s|{{DATABASE_URL}}|$WASP_DATABASE_URL|g; s|{{AUTH_SECRET}}|$WASP_JWT_SECRET|g; s|{{COOL_URL}}|$COOLIFY_BASE_URL|g; s~{{COOL_KEY}}~$COOLIFY_COOL_KEY~g; s|{{COOL_SERVER_UUID}}|$COOLIFY_SERVER_UUID|g; s|{{COOL_PROJECT_UUID}}|$COOLIFY_PROJECT_UUID|g; s|{{COOL_ENVIRONMENT_NAME}}|$COOL_ENVIRONMENT_NAME|g; s|{{COOL_GITHUB_APP_UUID}}|$COOLIFY_GITHUB_APP_UUID|g; s|{{COOL_GIT_PRIVATE}}|$GH_PRIVATE|g; s|{{COOL_GIT_REPO}}|$COOLIFY_GIT_REPOSITORY|g; s|{{COOL_GIT_BRANCH}}|$COOLIFY_GIT_BRANCH|g; s|{{COOL_CLIENT_DESCRIPTION}}|$COOL_CLIENT_DESCRIPTION|g; s|{{COOL_SERVER_DESCRIPTION}}|$COOL_SERVER_DESCRIPTION|g" .env.coolify); then
    echo -e "\033[33m✅ --- Successfully configured Coolify Environment file with your chosen settings ---\033[0m"
    echo
  else
    echo
    echo -e "\033[31m🛑 --- Failed to configure Coolify Environment file! See above for errors... ---\033[0m"
    echo
    exit 1
  fi

  # Let's make sure we add the Coolify Environment file to `.gitignore`
  if ! grep -q -z -E ".env\.coolify" .gitignore; then
    echo "" >> .gitignore
    echo "# Ignore the Coolify environment file." >> .gitignore
    echo "# This file is just for you (or the admin) and does not belong in a Git Repo!" >> .gitignore
    echo ".env.coolify" >> .gitignore
    echo -e "\033[33m✅ --- Updated \`.gitignore\` to be aware of the Coolify Environment file ---\033[0m"
  else
    echo -e "\033[33m✅ --- \`.gitignore\` is alread aware of the Coolify Environment file ---\033[0m"
  fi
  echo

  # Check if a .env.server file exists, if not, create one
  if [ ! -e .env.server ]; then
    touch .env.server
    echo -e "\033[33m✅ --- Created a new .env.server file for local development ---\033[0m"
    echo
  fi

  if ! grep -q -z -E "DATABASE_URL" .env.server; then
    if [ -z "$DEV_DATABASE_URL" ]; then
      echo "# Database URL for DEVELOPMENT ONLY (Production dB URL is set in Env Vars in Coolify)" >> .env.server
      echo "# DATABASE_URL=" >> .env.server
      echo -e "\033[33m✅ --- Added space for 'DATABASE_URL' to \`.env.server\` for Local Development ---\033[0m"
    else
      echo "# Database URL for DEVELOPMENT ONLY (Production dB URL is set in Env Vars in Coolify)" >> .env.server
      echo "DATABASE_URL=$DEV_DATABASE_URL" >> .env.server
      echo -e "\033[33m✅ --- Added Development dB URL to \`.env.server\` for Local Development ---\033[0m"
    fi
  else
    echo -e "\033[33m✅ --- \`.env.server\` already has a 'DATABASE_URL' entry for Local Development ---\033[0m"
  fi

  echo
  if ! grep -q -z -E "JWT_SECRET" .env.server; then
    LOCAL_JWT_SECRET=$(openssl rand -hex 32)
    echo "" >> .env.server
    echo "# JWT Secret for Wasp's Auth System (used for local dev only)" >> .env.server
    echo "JWT_SECRET=$LOCAL_JWT_SECRET" >> .env.server
    echo -e "\033[33m✅ --- Added 'JWT_SECRET' to \`.env.server\` for Local Development ---\033[0m"
  else
    echo -e "\033[33m✅ --- \`.env.server\` already has a 'JWT_SECRET' set up ---\033[0m"
  fi

  echo
  echo -e "\033[1;32m🤖 --- COOL-DEPLOY IS NOW FULLY SET UP! ---\033[0m"
  echo
fi # End of Coolify Environment file check / setup

if [ $FIRST_TIME_RUN -eq 1 ]; then # First time? Should we deploy?
  while true; do
    echo
    read -p $'\033[31mCONFIRM:\033[33m Would you like to run your first deployment? [y/n]:\033[0m ' DEPLOY_CONTINUE
    if [ "$DEPLOY_CONTINUE" == "y" ]; then
      FIRST_TIME_RUN=0
      break
    elif [ "$DEPLOY_CONTINUE" == "Y" ]; then
      FIRST_TIME_RUN=0
      break
    elif [ "$DEPLOY_CONTINUE" == "yes" ]; then
      FIRST_TIME_RUN=0
      break
    elif [ "$DEPLOY_CONTINUE" == "n" ]; then
      exit 0
      break
    elif [ "$DEPLOY_CONTINUE" == "N" ]; then
      exit 0
      break
    elif [ "$DEPLOY_CONTINUE" == "no" ]; then
      exit 0
      break
    fi
  done
  echo
  if [ -e ".env.coolify" ]; then
    # Load our Coolify config variables
    echo -e "\033[1;32m🤖 --- LOADING ENVIRONMENT VARIABLES FROM .env.coolify ---\033[0m"
    source .env.coolify
  else # throw error
    echo -e "\033[1;31m🛑 --- Error: Coolify Environment file not found! THIS SHOULD NOT HAPPEN! ---\033[0m"
    echo
    exit 1
  fi
fi # End check for first time run

# ------------------------------------------------------------------------------
# BELOW THIS LINE IS THE ACTUAL DEPLOYMENT SCRIPT
# ------------------------------------------------------------------------------

# Tell the client frontend where to find the server backend
REACT_APP_API_URL=$WASP_SERVER_URL

# Begin pre-deployment...
echo
echo -e "\033[1;32m🤖 --- BEGINNING PRE-DEPLOYMENT PROCESS...\033[0m"
echo

if [ ! -d "$WASP_PROJECT_DIR" ]; then
  # This should not ever happen!!!
  echo -e "\033[31m💀 --- Directory $WASP_PROJECT_DIR does not exist! ---\033[0m"
  echo
  exit 1
fi

cd $WASP_PROJECT_DIR

# Set all the different Coolify variables and settings for deployment
COOLIFY_VERSION=$(get_coolify_version)
set_payload_values_for_server_client

# Show the relevant information about the deployment and ask to confirm
echo -e "\033[1;36m🤖 --- WASP PROJECT & SERVER DEPLOYMENT INFO...\033[0m"
echo

echo -e "\033[1;43m• WASP PROJECT \033[3;43m$WASP_APP_NAME \033[0m"
echo -e "\033[1;33m - Source Repository:\033[0m \033[37m$git_repository:$git_branch ($git_commit_sha)\033[0m"
echo -e "\033[1;33m - Running on Wasp:\033[0m \033[31m$WASP_VERSION\033[0m"
echo -e "\033[1;33m - Coolify Version:\033[0m \033[31m$COOLIFY_VERSION\033[0m"
echo -e "\033[1;33m - Coolify Server UUID:\033[0m \033[32m$server_uuid\033[0m"
echo -e "\033[1;33m - Coolify Project UUID:\033[0m \033[32m$project_uuid\033[0m"
echo -e "\033[1;33m - Coolify Environment Name:\033[0m \033[32m$environment_name\033[0m"
if [ $GH_PRIVATE -eq 1 ]; then
  echo -e "\033[1;33m - Using Github App Key:\033[0m \033[32m$github_app_uuid\033[0m"
fi
echo -e "\033[1;33m - Database URI:\033[0m \033[31m$DATABASE_URL\033[0m"
echo -e "\033[1;33m - Local Project Directory:\033[0m $WASP_PROJECT_DIR"
echo -e "\033[1;33m - Local Client Directory:\033[0m $CLIENT_DEPLOY_DIR"
echo -e "\033[1;33m - Local Server Directory:\033[0m $SERVER_DEPLOY_DIR"
echo -e "\033[1;33m - Client URL:\033[0m \033[34m$client_domains:$client_ports_exposes\033[0m"
echo -e "\033[1;33m - Server URL:\033[0m \033[34m$server_domains:$server_ports_exposes\033[0m"
echo -e "\033[1;33m - JWT Secret:\033[0m \033[35m$JWT_SECRET\033[0m"
echo

# Get the commit message (if there is one)
if [ $# -gt 0 ]; then
    COMMIT_MSG="$1"
    echo -e "\033[1;33mGit Commit Message:\033[0m $COMMIT_MSG"
else
    COMMIT_MSG="Deployment from command line.


No commit message provided.
"
fi

while true; do
  echo
  read -p $'\033[1;31mCONFIRM:\033[0m \033[33mProceed with Deployment? [Y/n]:\033[0m ' DEPLOY_NOW_CONTINUE
  if [ "$DEPLOY_NOW_CONTINUE" == "y" ]; then
    break
  elif [ "$DEPLOY_NOW_CONTINUE" == "Y" ]; then
    break
  elif [ "$DEPLOY_NOW_CONTINUE" == "yes" ]; then
    break
  elif [ "$DEPLOY_NOW_CONTINUE" == "" ]; then
    # Default condition (yes)
    break
  elif [ "$DEPLOY_NOW_CONTINUE" == "n" ]; then
    exit 0
    break
  elif [ "$DEPLOY_NOW_CONTINUE" == "N" ]; then
    exit 0
    break
  elif [ "$DEPLOY_NOW_CONTINUE" == "no" ]; then
    exit 0
    break
  fi
done

# Get the start time
start_time=$(date +%s)

# ------------------------------------------------------------------------------
# TODO: From `api-test.sh`
echo "HERE IS WHERE WE WOULD BUILD THE PROJECT AND PUSH IT TO GIT!"
# ------------------------------------------------------------------------------

exit 1

# Begin Deployment Process!
cd $WASP_PROJECT_DIR
echo

if [ ! -d "$CLIENT_DEPLOY_DIR" ]; then
  echo -e "\033[31m💀 --- Error: \`$CLIENT_DEPLOY_DIR\` does not exist! Please delete \`.env.coolify\` and run script again to re-configure. ---\033[0m"
  echo
  exit 1
fi

if [ ! -d "$SERVER_DEPLOY_DIR" ]; then
  echo -e "\033[31m💀 --- Error: \`$SERVER_DEPLOY_DIR\` does not exist! Please delete \`.env.coolify\` and run script again to re-configure. ---\033[0m"
  echo
  exit 1
fi

echo -e "\033[1;31m❗️ --- CLEANING OUT OLD BUILDS...\033[0m"
echo
cd $WASP_PROJECT_DIR
rm -rf $SERVER_DEPLOY_DIR/db
rm -rf $SERVER_DEPLOY_DIR/sdk
rm -rf $SERVER_DEPLOY_DIR/server
rm -rf $SERVER_DEPLOY_DIR/src
rm -rf $SERVER_DEPLOY_DIR/package.json
rm -rf $SERVER_DEPLOY_DIR/package-lock.json
rm -rf $SERVER_DEPLOY_DIR/installedNpmDepsLog.json
rm -rf $SERVER_DEPLOY_DIR/Dockerfile
rm -rf $SERVER_DEPLOY_DIR/.waspinfo
rm -rf $SERVER_DEPLOY_DIR/.waspchecksums
rm -rf $SERVER_DEPLOY_DIR/.dockerignore
echo -e "\033[33m✅ --- Sanitized \`$SERVER_DEPLOY_DIR\`. ---\033[0m"
echo
rm -rf $CLIENT_DEPLOY_DIR/assets
rm -rf $CLIENT_DEPLOY_DIR/.gitkeep
rm -rf $CLIENT_DEPLOY_DIR/favicon.ico
rm -rf $CLIENT_DEPLOY_DIR/index.html
rm -rf $CLIENT_DEPLOY_DIR/*.html
rm -rf $CLIENT_DEPLOY_DIR/manifest.json
echo -e "\033[33m✅ --- Sanitized \`$CLIENT_DEPLOY_DIR\`. ---\033[0m"
echo

cd $WASP_PROJECT_DIR
if ! wasp clean; then
  echo -e "\033[1;31m💀 --- ERROR: Unknown Cleaning Failure Occured! Check above for details. ---\033[0m"
  echo
  exit 1
fi

echo
echo -e "\033[1;32m🤖 --- BUILDING SERVER...\033[0m"
cd $WASP_PROJECT_DIR
if ! wasp build; then
  echo -e "\033[1;31m💀 --- ERROR: Server Build Failure Occured! Check above for details. ---\033[0m"
  echo
  exit 1
fi

echo
echo -e "\033[1;32m🤖 --- BUILDING & BUNDLING CLIENT (REACT_APP_API_URL: \033[1;31m$REACT_APP_API_URL\033[1;32m)\033[0m"
cd $WASP_PROJECT_DIR
cd .wasp/build/web-app
if ! (npm install && REACT_APP_API_URL=$REACT_APP_API_URL npm run build); then
  echo -e "\033[1;31m💀 --- ERROR: Client Build Failure Occured! Check above for details. ---\033[0m"
  echo
  exit 1
fi

echo
echo -e "\033[1;32m🤖 --- SHIPPING INTO DEPLOYMENT DIRECTORIES...\033[0m"
echo
cd $WASP_PROJECT_DIR
mv -f .wasp/build/web-app/build/* $CLIENT_DEPLOY_DIR
echo -e "\033[33m✅ --- Moved static site files into \`$CLIENT_DEPLOY_DIR\`. ---\033[0m"
echo
mv -f .wasp/build/* $SERVER_DEPLOY_DIR
rm -rf $SERVER_DEPLOY_DIR/web-app/
echo -e "\033[33m✅ --- Moved server code & sdk and Dockerfile into \`$SERVER_DEPLOY_DIR\`. ---\033[0m"
echo

echo
echo -e "\033[1;33m🤖 --- BUILD AND PRE-DEPLOYMENT COMPLETE!\033[0m"

echo
echo -e "\033[1;32m🤖 --- DEPLOYING VIA GIT and COOLIFY WEBHOOKS...\033[0m"
echo

TIMESTAMP_UNIX=$(date +%s)
TIMESTAMP_HUMAN=$(date "+%I:%M:%S %p on %m/%d/%Y")
COMMIT_MSG="Cool-Deploy: $COMMIT_MSG

Code pushed to repository at: $TIMESTAMP_HUMAN.
UNIX Epoc: [$TIMESTAMP_UNIX]
"

cd $WASP_PROJECT_DIR
git add .
git commit -m "$COMMIT_MSG"
if git push; then
  echo
  echo -e "\033[33m✅ --- Successfully pushed Everything(tm) to GitHub. ---\033[0m"
else
  echo
  echo -e "\033[1;31m🛑 --- Failed to push Anything to GitHub! ---\033[0m"
fi

echo
echo -e "Your App is available at: \033[1;34m$WASP_WEB_CLIENT_URL\033[0m"
echo

if [ ! -z "$dev_db_port" ]; then
  echo -e "Remember to expose port $dev_db_port on your server's firewall to allow access to the Development Database."
  echo
fi

# Get the end time and calculate the difference
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

MINUTE_SUFIX="minute"

if [ $elapsed_time -gt 59 ]; then
    minutes=$((elapsed_time / 60))
    seconds=$((elapsed_time % 60))
    if [ $minutes -gt 1 ]; then
      MINUTE_SUFIX="minutes"
    fi
    echo -e "\033[1;33m🎉 --- DEPLOYMENT COMPLETED IN: $minutes $MINUTE_SUFIX and $seconds seconds!\033[0m"
else
    echo -e "\033[1;33m🎉 --- DEPLOYMENT COMPLETED IN: $elapsed_time seconds!\033[0m"
fi
