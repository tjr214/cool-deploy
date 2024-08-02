#!/bin/bash

source .env.coolify

COOLIFY_API_KEY="1|CWjPJnXad9NoWZogwjhebgvBEMsxkRhm0fUKAQCz9b727414"
COOLIFY_BASE_URL="https://timlify.thetjr.com"
BEARER="Authorization: Bearer $COOLIFY_API_KEY"

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

detect_jq

# local colors=(black red green yellow blue magenta cyan white reset)
# local color_codes=(30 31 32 33 34 35 36 37 0)

# local styles=(bold italic underline strikethrough)
# local style_codes=(1 3 4 9)

# local backgrounds=(black red green yellow blue magenta cyan white)
# local background_codes=(40 41 42 43 44 45 46 47)

get_coolify_version() {
  local version=$(curl -s --request GET \
    --url $COOLIFY_BASE_URL/api/v1/version \
    --header "$BEARER")
echo "$version"
}

list_coolify_servers() {
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


list_coolify_servers
while true; do
  read -p $'\033[33mEnter the UUID of the Server to Deploy to:\033[0m ' COOLIFY_SERVER_UUID
  if [ -z "$COOLIFY_SERVER_UUID" ]; then
    echo -e "\033[31mPlease enter a valid UUID!\033[0m"
  else
    list_coolify_servers "$COOLIFY_SERVER_UUID"
    if [ $? -eq 0 ]; then
      break
    fi
  fi
done


COOLIFY_VERSION=$(get_coolify_version)
echo -e "\033[33mCoolify API Key:\033[0m $COOLIFY_API_KEY"
echo -e "\033[33mCoolify Version:\033[0m $COOLIFY_VERSION"
echo -e "\033[33mDeploying to Server:\033[0m $COOLIFY_SERVER_UUID\033[0m"
