#!/bin/bash

# Source our variables from the generated env file
source .env.coolify

# Project path variable
WASP_PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PARENT_DIR=$(dirname "$WASP_PROJECT_DIR")

# Deploy directories
DEPLOY_DIR=$WASP_PROJECT_DIR/deploy
CLIENT_DEPLOY_DIR=$DEPLOY_DIR/client
SERVER_DEPLOY_DIR=$DEPLOY_DIR/server

# Tell the client frontend where to find the server backend
REACT_APP_API_URL=$WASP_SERVER_URL

# Get the start time
start_time=$(date +%s)

# Begin!
echo
echo -e "\033[1;32m🤖 --- BEGINNING PRE-DEPLOYMENT PROCESS...\033[0m"
echo

if [ ! -d "$WASP_PROJECT_DIR" ]; then
  # This should not ever happen!!!
  echo -e "\033[31m💀 --- Directory $WASP_PROJECT_DIR does not exist! ---\033[0m"
  echo
  exit 1
fi

echo -e "\033[1;36m🤖 --- PROJECT INFO...\033[0m"
echo

echo -e "\033[1;33mWasp Project Dir:\033[0m $WASP_PROJECT_DIR"
echo -e "\033[1;33mClient Directory:\033[0m $CLIENT_DEPLOY_DIR"
echo -e "\033[1;33mServer Directory:\033[0m $SERVER_DEPLOY_DIR"
echo -e "\033[1;33mClient URL:\033[0m $WASP_WEB_CLIENT_URL"
echo -e "\033[1;33mServer URL:\033[0m $REACT_APP_API_URL"
echo

# Get back to the `project` directory that contains the wasp dir and the git deploy dirs
cd $WASP_PROJECT_DIR

if [ ! -d "$CLIENT_DEPLOY_DIR" ]; then
  echo -e "\033[31m💀 --- Error: \`$CLIENT_DEPLOY_DIR\` does not exist! Please run setup script again. ---\033[0m"
  echo
  exit 1
fi

if [ ! -d "$SERVER_DEPLOY_DIR" ]; then
  echo -e "\033[31m💀 --- Error: \`$SERVER_DEPLOY_DIR\` does not exist! Please run setup script again. ---\033[0m"
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
echo -e "\033[1;32m🤖 --- SHIPPING INTO DEPLOY DIRECTORIES...\033[0m"
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

TIMESTAMP=$(date +%s)
if [ $# -gt 0 ]; then
    COMMIT_MSG="$1 [$TIMESTAMP]"
else
    COMMIT_MSG="Commit [$TIMESTAMP]"
fi

cd $WASP_PROJECT_DIR
git add .
git commit -m "Auto-Deploy: $COMMIT_MSG"
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

if [ $elapsed_time -gt 59 ]; then
    minutes=$((elapsed_time / 60))
    seconds=$((elapsed_time % 60))
    echo -e "\033[1;33m🤖 --- DEPLOYMENT COMPLETED IN: $minutes minute and $seconds seconds!\033[0m"
else
    echo -e "\033[1;33m🤖 --- DEPLOYMENT COMPLETED IN: $elapsed_time seconds!\033[0m"
fi
