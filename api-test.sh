#!/bin/bash

source .env.coolify

# COOLIFY_API_KEY=""
# COOLIFY_BASE_URL=""
BEARER="Authorization: Bearer $COOLIFY_API_KEY"

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
  if [ ! -z "$1" ]; then
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
# LIST_COOLIFY_PROJECTS
# ------------------------------------------------------------------------------
list_coolify_projects() {
  local projects=$(curl -s --request GET \
    --url $COOLIFY_BASE_URL/api/v1/projects \
    --header "$BEARER")
  local project_count=$(jq '. | length' <<< "$projects")
  for ((i = 0; i < project_count; i++)); do # Loop through all projects
    local id=$(jq -r ".[$i].id" <<< "$projects")
    local uuid=$(jq -r ".[$i].uuid" <<< "$projects")
    local name=$(jq -r ".[$i].name" <<< "$projects")
    project_info=$(curl -s --request GET \
      --url $COOLIFY_BASE_URL/api/v1/projects/$uuid \
      --header "$BEARER")
    local description=$(jq -r ".description" <<< "$project_info")
    # local environments=$(jq -r ".environments" <<< "$project_info")
    # echo -e "$environments"
    # local created_at=$(jq -r ".created_at" <<< "$project_info")
    # local updated_at=$(jq -r ".updated_at" <<< "$project_info")
    echo -e "\033[33mProject-$((i+1)):\033[0m \033[1;31m$name\033[0m"
    echo -e "  Description: $description"
    echo -e "  ID: $id"
    echo -e "  UUID: \033[1;37m$uuid\033[0m"
    # echo -e "  Created At: $created_at"
    # echo -e "  Updated At: $updated_at"
  done # End of project loop
}

# TEST_UUID="tscs8k4"

# local colors=(black red green yellow blue magenta cyan white reset)
# local color_codes=(30 31 32 33 34 35 36 37 0)

# local styles=(bold italic underline strikethrough)
# local style_codes=(1 3 4 9)

# local backgrounds=(black red green yellow blue magenta cyan white)
# local background_codes=(40 41 42 43 44 45 46 47)



# Detect if the `jq` command line tool is installed and available
detect_jq

# Get the UUID of the server to deploy to:
# get_coolify_servers
# while true; do
#   read -p $'\033[33mEnter the UUID of the Server to Deploy to:\033[0m ' COOLIFY_SERVER_UUID
#   if [ -z "$COOLIFY_SERVER_UUID" ]; then
#     echo -e "\033[31mPlease enter a valid UUID!\033[0m"
#   else
#     get_coolify_servers "$COOLIFY_SERVER_UUID"
#     if [ $? -eq 0 ]; then
#       break
#     fi
#   fi
# done

# Now, we need to select the Coolify Project to house the deployments
while true; do
  read -p $'\033[33mDeploy to New Project or Add to existing one? \033[31mDefault: New \033[33m[New/List/Add]:\033[0m ' new_list_or_add
  if [ -z "$new_list_or_add" ]; then
    new_list_or_add="NEW"
  fi
  new_list_or_add=$(echo "$new_list_or_add" | tr '[:lower:]' '[:upper:]')
  if [ "$new_list_or_add" == "NEW" ]; then
    echo -e "NEW"
    break
  elif [ "$new_list_or_add" == "LIST" ]; then
    list_coolify_projects
  elif [ "$new_list_or_add" == "ADD" ]; then
    echo -e "ADD"
    break
  fi
done



# Display the data we got from Coolify
COOLIFY_VERSION=$(get_coolify_version)
echo
echo -e "\033[33mCoolify API Key:\033[0m $COOLIFY_API_KEY"
echo -e "\033[33mCoolify Version:\033[0m $COOLIFY_VERSION"
echo -e "\033[33mDeploying to Server:\033[0m $COOLIFY_SERVER_UUID\033[0m"

COOLIFY_PROJECT_UUID=$(get_coolify_project_uuid)
COOLIFY_ENVIRONMENT_NAME="production"
COOLIFY_GITHUB_APP_UUID=""
COOLIFY_GIT_REPO=""
COOLIFY_GIT_BRANCH="main"
COOLIFY_CLIENT_PORTS_EXPOSES="80"
COOLIFY_SERVER_PORTS_EXPOSES="$PORT"
COOLIFY_CLIENT_BUILDPACK="nixpacks"
COOLIFY_SERVER_BUILDPACK="dockerfile"
COOLIFY_CLIENT_APP_NAME="My Cool Fucking Frontent"
COOLIFY_SERVER_APP_NAME="My Cool Fucking Backend"
COOLIFY_CLIENT_DESCRIPTION="This is a cool fucking frontend"
COOLIFY_SERVER_DESCRIPTION="This is a cool fucking backend"
COOLIFY_CLIENT_IS_STATIC="true"
COOLIFY_CLIENT_BASE_DIR="/"
COOLIFY_SERVER_BASE_DIR="/deploy/server"
COOLIFY_CLIENT_PUBLISH_DIR="/deploy/client"
COOLIFY_SERVER_DOCKERFILE="/Dockerfile"
COOLIFY_CLIENT_INSTANT_DEPLOY="true"
COOLIFY_SERVER_INSTANT_DEPLOY="true"
