#!/bin/bash

set_server_env() {
  if [ -z "$1" ]; then
    if [ ! -z "$2" ]; then
      echo -e "ERROR: No 'Key' Provided for Environment Variable Value '$2'!"
    else
      echo -e "ERROR: No 'Key' or 'Value' Provided for Environment Variable!"
    fi
    echo
    echo -e "\033[1;31m💀 --- COOLIFY ERROR: Server Set Env Variable Failed! See above for possible details... ---\033[0m"
    exit 1
  fi
  if [ -z "$2" ]; then
    echo "ERROR: No 'Value' Provided for Environment Variable Key '$1'!"
    echo
    echo -e "\033[1;31m💀 --- COOLIFY ERROR: Server Set Env Variable Failed! See above for possible details... ---\033[0m"
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
  echo -e "$env_payload"
}




if [ -e ".env.server" ]; then
  # Declare an array to store the client env variables
  declare -a server_env_array

  # Read the client env file line by line and split into key-value pairs
  while IFS='=' read -r key value; do # move the input into the array
    if [[ $key != "" ]]; then # Don't want empty lines
      if [[ $key != DATABASE_URL ]]; then # Ignore the dev db url
        if [[ $key != JWT_SECRET ]]; then # Ignore the dev JWT secret
          if [[ $key != PORT ]]; then # Ignore the dev server port
            if [[ $key != [#[:space:]]* ]]; then # Ignore comments and whitespace
                server_env_array+=("${key}" "${value}")
            fi
          fi
        fi
      fi
    fi
  done < .env.server # redirect the client env file to the `read` command
  # DEBUG: Print the array
  # for ((i=0; i<${#server_env_array[@]}; i+=2)); do
  #   echo "Key: ${server_env_array[$i]}, Value: ${server_env_array[$i+1]}"
  # done

  # Set the env vars
  for ((i=0; i<${#server_env_array[@]}; i+=2)); do
    set_server_env "${server_env_array[$i]}" "${server_env_array[$i+1]}"
  done

  # And again for the Preview Deploys
  for ((i=0; i<${#server_env_array[@]}; i+=2)); do
    set_server_env "${server_env_array[$i]}" "${server_env_array[$i+1]}" true
  done
fi
