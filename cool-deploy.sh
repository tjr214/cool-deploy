#!/bin/bash

# Some project variables
WASP_PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PARENT_DIR=$(dirname "$WASP_PROJECT_DIR")
FIRST_TIME_RUN=0
COOLIFY_API_KEY=""
BEARER=""
GH_PRIVATE=0

# JWT_SECRET=0

# Deploy directories
DEPLOY_DIR=$WASP_PROJECT_DIR/deploy
CLIENT_DEPLOY_DIR=$DEPLOY_DIR/client
SERVER_DEPLOY_DIR=$DEPLOY_DIR/server

# Get the app name and version of the Wasp App
cd $WASP_PROJECT_DIR
WASP_APP_NAME=$(grep -o 'app \w\+' main.wasp | cut -d' ' -f2)
WASP_VERSION=$(awk '/wasp: {/,/}/ {if ($1 == "version:") {gsub(/[",]/, "", $2); sub(/^\^/, "", $2); print $2; exit}}' main.wasp)

# if grep -q -z -E "JWT_SECRET=" .env.server; then
#   WASP_JWT_SECRET=$(grep -E "JWT_SECRET=" .env.server | cut -d '=' -f 2-)
#   JWT_SECRET=1
# fi

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
# CONFIGURE_SERVER_PROJECT_KEY
# TODO
# ------------------------------------------------------------------------------
configure_server_project_key() {
  echo
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
  return 0
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
      echo -e "\033[1;31m🛑 --- ERROR: Coolify API Key not found in \`.env.coolify\`! ---\033[0m"
      echo
      exit 1
  fi
  BEARER="Authorization: Bearer $COOLIFY_API_KEY"
  configure_server_project_key # if any of this is missing, go grab it from the user
else # Configure our `cool-deploy`` script!
  echo -e "\033[1;32m🤖 --- LET'S GET COOL-DEPLOY SET UP! ---\033[0m"
  SETTINGS_CONFIRM=0
  FIRST_TIME_RUN=1
  FINISHED_COOLIFY_SETUP=0

  # Get the Coolify API Key
  while true; do
    read -p $'\033[33mEnter your Coolify API Key:\033[0m ' COOLIFY_API_KEY
    if [ -z "$COOLIFY_API_KEY" ]; then
      echo -e "\033[31mPlease enter a valid Coolify API Key!\033[0m"
    else
      break
    fi
  done
  BEARER="Authorization: Bearer $COOLIFY_API_KEY"

  while [ $SETTINGS_CONFIRM -eq 0 ]; do # Get user inout and configure vars
    # Configure the Coolify Server, Project, and optional Github App Key
    configure_server_project_key
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
    read -p $'\033[33mDatabase URL (or, hit enter to leave blank for now):\033[0m ' WASP_DATABASE_URL
    read -p $'\033[33mJWT Secret Key (or, hit enter to generate):\033[0m ' WASP_JWT_SECRET

    # if [ $JWT_SECRET -eq 0 ]; then
    #   read -p $'\033[33mJWT Secret Key (or, hit enter to generate):\033[0m ' WASP_JWT_SECRET
    # else
    #   echo -e "\033[33m🤙 --- Using JWT Secret already defined in \`.env.server\`. ---\033[0m"
    # fi
    
    # Finalize the variables' content
    REACT_APP_API_URL=$WASP_SERVER_URL
    WASP_SERVER_PORT=${WASP_SERVER_PORT:-3000}
    WASP_JWT_SECRET=${WASP_JWT_SECRET:-$(openssl rand -hex 32)}
    WASP_DATABASE_URL=${WASP_DATABASE_URL:-postgres://}

    # Print variables and confirm selections
    echo
    echo -e "\033[1;36m🤖 --- SETTINGS AND ENVIRONMENT CONFIGURATION ---\033[0m"
    echo
    echo -e "\033[1;34mWASP_WEB_CLIENT_URL\033[0m=$WASP_WEB_CLIENT_URL"
    echo -e "\033[1;34mWASP_SERVER_URL\033[0m=$REACT_APP_API_URL"
    echo -e "\033[1;34mWASP_SERVER_PORT\033[0m=$WASP_SERVER_PORT"
    echo -e "\033[1;34mDATABASE_URL\033[0m=$WASP_DATABASE_URL"
    echo -e "\033[1;34mJWT_SECRET\033[0m=$WASP_JWT_SECRET"
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
    fi
  done # End of settings config loop

  echo
  echo -e "\033[33m✅ --- Configured settings for \`cool-deploy.sh\`! ---\033[0m"
  echo

  cd $WASP_PROJECT_DIR

  # Create .env.coolify file template
  if (echo "# Frontend URL (Note: this cannot be changed without rerunning \`./cool-deploy.sh\`!)
WASP_WEB_CLIENT_URL={{FRONT_URL}}

# Backend Server
WASP_SERVER_URL={{BACK_URL}}
PORT={{BACK_PORT}}

# Database URL
DATABASE_URL={{DATABASE_URL}}

# JWT Secret for Wasp's Auth System
JWT_SECRET={{AUTH_SECRET}}" > .env.coolify); then
    echo -e "\033[33m✅ --- Successfully created Coolify Environment Template file ---\033[0m"
    echo
  else
    echo
    echo -e "\033[31m🛑 --- Failed to create \`.env.coolify\`! See above for possible errors... ---\033[0m"
    echo
    exit 1
  fi

  # Replace the Env placeholders in `.coolify.env`
  if (sed -i "" "s|{{FRONT_URL}}|$WASP_WEB_CLIENT_URL|g; s|{{BACK_URL}}|$REACT_APP_API_URL|g; s|{{BACK_PORT}}|$WASP_SERVER_PORT|g; s|{{DATABASE_URL}}|$WASP_DATABASE_URL|g; s|{{AUTH_SECRET}}|$WASP_JWT_SECRET|g" .env.coolify); then
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
    echo "# Database URL for DEVELOPMENT ONLY (Production dB URL is set in Env Vars in Coolify)" >> .env.server
    echo "# DATABASE_URL=" >> .env.server
    echo -e "\033[33m✅ --- Added space for 'DATABASE_URL' to \`.env.server\` for Local Development ---\033[0m"
  else
    echo -e "\033[33m✅ --- \`.env.server\` already has a 'DATABASE_URL' entry for Local Development ---\033[0m"
  fi

  echo
  if ! grep -q -z -E "JWT_SECRET" .env.server; then
    LOCAL_JWT_SECRET=$(openssl rand -hex 32)
    echo "# JWT Secret for Wasp's Auth System (used for local dev only)" >> .env.server
    echo "JWT_SECRET=$LOCAL_JWT_SECRET" >> .env.server
    echo -e "\033[33m✅ --- Added 'JWT_SECRET' to \`.env.server\` for Local Development ---\033[0m"
  else
    echo -e "\033[33m✅ --- \`.env.server\` already has a 'JWT_SECRET' set up ---\033[0m"
  fi

  echo
  echo
  echo -e "\033[1;32m🤖 --- COOL-DEPLOY IS NOW FULLY SET UP! ---\033[0m"
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

COOLIFY_VERSION=$(get_coolify_version)
project_uuid="$COOLIFY_PROJECT_UUID"
server_uuid="$COOLIFY_SERVER_UUID"
COOLIFY_ENVIRONMENT_NAME=${COOLIFY_ENVIRONMENT_NAME:-production}
environment_name="$COOLIFY_ENVIRONMENT_NAME"
if [ $GH_PRIVATE -eq 1 ]; then
  github_app_uuid="$COOLIFY_GITHUB_APP_UUID"
fi

# Set Github variables
# TODO: grab these values from the user!
# git_repository="tjr214/wasp-todo-demo-app"
git_repository="https://github.com/tjr214/wasp-todo-demo-app.git" # TODO: grab these values from the user!
git_branch="$COOLIFY_GIT_BRANCH" # TODO: grab these values from the user!
git_commit_sha="$COOLIFY_GIT_COMMIT_SHA" # TODO: grab these values from the user!

# Set Coolify deployment variables
client_ports_exposes="80"
client_build_pack="static"
client_description="This is a cool fucking frontend" # TODO: grab these values from the user!
client_domains="$WASP_WEB_CLIENT_URL"
client_base_directory="/deploy/client"
client_instant_deploy="false"

server_ports_exposes="$PORT"
server_build_pack="dockerfile"
server_description="This is a cool fucking Backend" # TODO: grab these values from the user!
server_domains="$WASP_SERVER_URL"
server_base_directory="/deploy/server"
server_instant_deploy="false"

echo -e "\033[1;36m🤖 --- PROJECT & DEPLOYMENT INFO...\033[0m"
echo

echo -e "\033[1;43m• WASP PROJECT \033[3;43m$WASP_APP_NAME \033[0m"
echo -e "\033[1;33m - Source Repository:\033[0m \033[37m$git_repository:$git_branch ($git_commit_sha)\033[0m"
echo -e "\033[1;33m - Running on Wasp:\033[0m \033[31m$WASP_VERSION\033[0m"
echo -e "\033[1;33m - Coolify Version:\033[0m \033[31m$COOLIFY_VERSION\033[0m"
echo -e "\033[1;33m - Coolify Server UUID:\033[0m \033[32m$server_uuid\033[0m"
echo -e "\033[1;33m - Coolify Project UUID:\033[0m \033[32m$project_uuid\033[0m"
echo -e "\033[1;33m - Coolify Environment Name:\033[0m \033[31m$environment_name\033[0m"
if [ $GH_PRIVATE -eq 1 ]; then
  echo -e "\033[1;33m - Coolify is using Github App Key:\033[0m \033[32m$github_app_uuid\033[0m"
fi
echo -e "\033[1;33m - Local Project Directory:\033[0m $WASP_PROJECT_DIR"
echo -e "\033[1;33m - Local Client Directory:\033[0m $CLIENT_DEPLOY_DIR"
echo -e "\033[1;33m - Local Server Directory:\033[0m $SERVER_DEPLOY_DIR"
echo -e "\033[1;33m - Client URL:\033[0m \033[34m$WASP_WEB_CLIENT_URL\033[0m"
echo -e "\033[1;33m - Server URL:\033[0m \033[34m$REACT_APP_API_URL\033[0m"
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
