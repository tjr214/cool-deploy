#!/bin/bash

if [ $# -gt 0 ]; then
  echo "Here is the Generated String: \`$@\`"
  exit 0
fi

if [ -e ".env.client" ]; then
  # Declare an array to store the client env variables
  declare -a client_env_array

  # Read the client env file line by line and split into key-value pairs
  while IFS='=' read -r key value; do # move the input into the array
    # We are only interested in the `REACT_APP_` variables
    if [[ $key == REACT_APP_* ]]; then
        client_env_array+=("${key}" "${value}")
    fi
  done < .env.client # redirect the client env file to the `read` command

  # Print the array
  for ((i=0; i<${#client_env_array[@]}; i+=2)); do
    echo "Key: ${client_env_array[$i]}, Value: ${client_env_array[$i+1]}"
  done

  REACT_APP_CLIENT_ENV_STRING=""

  for ((i=0; i<${#client_env_array[@]}; i+=2)); do
    REACT_APP_CLIENT_ENV_STRING="${REACT_APP_CLIENT_ENV_STRING}${client_env_array[$i]}=${client_env_array[$i+1]} "
  done

  echo $REACT_APP_CLIENT_ENV_STRING
  echo
  echo

  ./envs-client-test.sh "$REACT_APP_CLIENT_ENV_STRING"
fi
