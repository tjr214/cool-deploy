#!/bin/bash

# Source our variables from the generated env file
source .env.coolify

# Project path variables
WASP_PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MAIN_PROJECT_DIR=$(dirname "$WASP_PROJECT_DIR")

# Deplot directories
CLIENT_DEPLOY_DIR=$WASP_PROJECT_DIR/deploy/cool_client
SERVER_DEPLOY_DIR=$WASP_PROJECT_DIR/deploy/cool_server

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

echo -e "\033[1;33mMain Project Dir:\033[0m $MAIN_PROJECT_DIR"
echo -e "\033[1;33mWasp Project Dir:\033[0m $WASP_PROJECT_DIR"
echo -e "\033[1;33mClient Location:\033[0m $WASP_WEB_CLIENT_URL"
echo -e "\033[1;33mServer Location:\033[0m $REACT_APP_API_URL"
echo

# Get back to the `project` directory that contains the wasp dir and the git deploy dirs
cd $MAIN_PROJECT_DIR

if [ ! -d "client_build" ]; then
  echo -e "\033[31m💀 --- Error: client_build/ directory does not exist! Please run setup script again. ---\033[0m"
  echo
  exit 1
fi

if [ ! -d "server_build" ]; then
  echo -e "\033[31m💀 --- Error: server_build/ directory does not exist! Please run setup script again. ---\033[0m"
  echo
  exit 1
fi

echo -e "\033[1;31m❗️ --- CLEANING OUT OLD BUILDS...\033[0m"
echo
rm -rf server_build/db
rm -rf server_build/sdk
rm -rf server_build/server
rm -rf server_build/src
rm -rf server_build/package.json
rm -rf server_build/package-lock.json
rm -rf server_build/installedNpmDepsLog.json
rm -rf server_build/Dockerfile
rm -rf server_build/.waspinfo
rm -rf server_build/.waspchecksums
rm -rf server_build/.dockerignore
echo -e "\033[33m✅ --- Sanitized server_build/ directory. ---\033[0m"
echo
rm -rf client_build/assets
rm -rf client_build/.gitkeep
rm -rf client_build/favicon.ico
rm -rf client_build/index.html
rm -rf client_build/*.html
rm -rf client_build/manifest.json
echo -e "\033[33m✅ --- Sanitized client_build/ directory. ---\033[0m"
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
echo -e "\033[1;32m🤖 --- SHIPPING INTO DIST FOLDERS...\033[0m"
echo
cd $WASP_PROJECT_DIR
mv -f .wasp/build/web-app/build/* ../client_build
echo -e "\033[33m✅ --- Moved static site files into client_build/ directory. ---\033[0m"
echo
mv -f .wasp/build/* ../server_build
rm -rf ../server_build/web-app/
echo -e "\033[33m✅ --- Moved server code & sdk and Dockerfile into server_build/ directory. ---\033[0m"
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

cd $MAIN_PROJECT_DIR
cd client_build
git add .
git commit -m "Auto-Deploy: $COMMIT_MSG"
if git push; then
  echo
  echo -e "\033[33m✅ --- Successfully pushed Client to GitHub. ---\033[0m"
else
  echo
  echo -e "\033[1;31m🛑 --- Failed to push Client to GitHub! ---\033[0m"
fi
echo

cd $MAIN_PROJECT_DIR
cd server_build
git add .
git commit -m "Auto-Deploy: $COMMIT_MSG"
if git push; then
  echo
  echo -e "\033[33m✅ --- Successfully pushed Server to GitHub. ---\033[0m"
else
  echo
  echo -e "\033[1;31m🛑 --- Failed to push Server to GitHub! ---\033[0m"
fi
echo
cd $WASP_PROJECT_DIR

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
