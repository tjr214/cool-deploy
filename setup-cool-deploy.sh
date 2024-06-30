#!/bin/bash

# Get user input for the variables:
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

read -p $'\033[33mWhat port should the server run on? (default 3001):\033[0m ' WASP_SERVER_PORT
read -p $'\033[33mJWT Secret Key (or, hit enter to generate):\033[0m ' WASP_JWT_SECRET
read -p $'\033[33mDatabase URL (or, hit enter to leave blank for now):\033[0m ' WASP_DATABASE_URL

while true; do
  read -p $'\033[33mFrontend Git Repo URL (ex: https://github.com/USERNAME/wasp-client-repo.git):\033[0m ' WASP_GIT_CLIENT_REPO
  if [ -z "$WASP_GIT_CLIENT_REPO" ]; then
    echo -e "\033[31mPlease enter a valid Github URL!\033[0m"
  else
    break
  fi
done

while true; do
  read -p $'\033[33mServer Git Repo URL (ex: https://github.com/USERNAME/wasp-server-repo.git):\033[0m ' WASP_GIT_SERVER_REPO
  if [ -z "$WASP_GIT_SERVER_REPO" ]; then
    echo -e "\033[31mPlease enter a valid Github URL!\033[0m"
  else
    break
  fi
done

# Finalize the variables' content
REACT_APP_API_URL=$WASP_WEB_CLIENT_URL
WASP_SERVER_PORT=${WASP_SERVER_PORT:-3001}
WASP_JWT_SECRET=${WASP_JWT_SECRET:-$(openssl rand -hex 32)}
WASP_DATABASE_URL=${WASP_DATABASE_URL:-postgres://wasp:wasp@localhost:5432/wasp}

# Print and confirm
echo -e "WASP_WEB_CLIENT_URL=$REACT_APP_API_URL"
echo -e "WASP_SERVER_URL=$WASP_SERVER_URL"
echo -e "PORT=$WASP_SERVER_PORT"
echo -e "DATABASE_URL=$WASP_DATABASE_URL"
echo -e "JWT_SECRET=$WASP_JWT_SECRET"

echo -e "GIT_CLIENT_REPO=$WASP_GIT_CLIENT_REPO"
echo -e "GIT_SERVER_REPO=$WASP_GIT_SERVER_REPO"

# DELETE THIS PART!!!
rm -rf .coolify.env
cp template.coolify.env .coolify.env

# Download `cool-deploy.sh` script to the current directory
curl -o cool-deploy.sh https://github.com/tjr214/cool-deploy/raw/main/cool-deploy.sh

# Download `template.coolify.env` file to the current directory
curl -o .coolify.env https://github.com/tjr214/cool-deploy/raw/main/template.coolify.env
# mv template.coolify.env .coolify.env

# Replace the placeholders in `.coolify.env`
sed -i "" "s|{{FRONT_URL}}|$REACT_APP_API_URL|g; s|{{BACK_URL}}|$WASP_SERVER_URL|g; s|{{BACK_PORT}}|$WASP_SERVER_PORT|g; s|{{DATABASE_URL}}|$WASP_DATABASE_URL|g; s|{{AUTH_SECRET}}|$WASP_JWT_SECRET|g; s|{{GIT_CLIENT_URL}}|$WASP_GIT_CLIENT_REPO|g; s|{{GIT_SERVER_URL}}|$WASP_GIT_SERVER_REPO|g" .coolify.env

# Let's make sure we add the Coolify Environemnt file to `.gitignore`
if ! grep -q -z -E ".coolify\.env" .gitignore; then
  echo "" >> .gitignore
  echo "# Ignore the Coolify environment file." >> .gitignore
  echo "# This file is just for you (or the admin) and does not belong in a Git Repo!" >> .gitignore
  echo ".coolify.env" >> .gitignore
fi

# Run Initial Deployment!
# ./cool-deploy.sh
