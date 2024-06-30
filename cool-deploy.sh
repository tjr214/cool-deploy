#!/bin/bash

# Source our variables from the generated env file
source .coolify.env

# Project path variables
WASP_PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MAIN_PROJECT_DIR=$(dirname "$WASP_PROJECT_DIR")

# Set some variables for internal use
REACT_APP_API_URL=$WASP_WEB_CLIENT_URL
DO_INIT=0

# Get the start time
start_time=$(date +%s)

# Begin!
echo
echo -e "\033[1;32m🤖 --- BEGINNING PRE-DEPLOYMENT PROCESS...\033[0m"
echo

if [ ! -d "$WASP_PROJECT_DIR" ]; then
  # This should not ever happen!!!
  echo -e "\033[31m🛑 --- Directory $WASP_PROJECT_DIR does not exist! ---\033[0m"
  echo
  exit 1
fi

echo -e "\033[1;36m🤖 --- PROJECT INFO...\033[0m"
echo

echo -e "\033[1;33mMain Project Dir:\033[0m $MAIN_PROJECT_DIR"
echo -e "\033[1;33mWasp Project Dir:\033[0m $WASP_PROJECT_DIR"
echo -e "\033[1;33mClient URL Location:\033[0m $REACT_APP_API_URL"
echo

# Get back to the `project` directory that contains the wasp dir and the git deploy dirs
cd $MAIN_PROJECT_DIR

if [ ! -d "client_build" ]; then
  mkdir -p "client_build"
  DO_INIT=1
  echo -e "\033[33m✅ --- Created client_build/ directory. ---\033[0m"
  echo
fi

if [ ! -d "server_build" ]; then
  mkdir -p "server_build"
  DO_INIT=1
  echo -e "\033[33m✅ --- Created server_build/ directory. ---\033[0m"
  echo
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
echo -e "\033[1;32m🤖 --- BUILDING CLIENT to be hosted @ \033[1;31m$REACT_APP_API_URL...\033[0m"
cd $WASP_PROJECT_DIR
cd .wasp/build/web-app
if ! (npm install && REACT_APP_API_URL=$REACT_APP_API_URL npm run build); then
  echo -e "\033[1;31m💀 --- ERROR: Client Build Failure Occured! Check above for details. ---\033[0m"
  echo
  exit 1
fi

echo
echo -e "\033[1;32m🤖 --- COPYING INTO DIST FOLDERS...\033[0m"
echo
cd $WASP_PROJECT_DIR
cp -Rf .wasp/build/web-app/build/ ../client_build
echo -e "\033[33m✅ --- Copied static site files into client_build/ directory. ---\033[0m"
echo
cp -Rf .wasp/build/ ../server_build
rm -rf ../server_build/web-app/
echo -e "\033[33m✅ --- Copied server code & sdk and Dockerfile into server_build/ directory. ---\033[0m"
echo

echo
echo -e "\033[1;33m🤖 --- BUILD AND PRE-DEPLOYMENT COMPLETE!\033[0m"

echo
echo -e "\033[1;32m🤖 --- DEPLOYING VIA GIT and COOLIFY WEBHOOKS...\033[0m"
echo

if [ $DO_INIT -eq 1 ]; then
  echo -e "\033[33m🤖 --- WILL INIT COMMIT DIRECTORIES...\033[0m"
  echo
fi

TIMESTAMP=$(date +%s)
if [ $# -gt 0 ]; then
    COMMIT_MSG="$1 [$TIMESTAMP]"
else
    COMMIT_MSG="Commit [$TIMESTAMP]"
fi

cd $MAIN_PROJECT_DIR
cd client_build
if [ $DO_INIT -eq 1 ]; then
  git init
  git add .
  git commit -m "Auto-Deploy: Init Commit [$TIMESTAMP]"
  git remote add origin $GIT_CLIENT_REPO
  git branch -M main
  if git push -u origin main; then
    echo
    echo -e "\033[33m✅ --- Successfully pushed Client to GitHub and linked to remote origin. ---\033[0m"
  else
    echo
    echo -e "\033[1;31m🛑 --- Failed to push Client to GitHub and link to remote origin! ---\033[0m"
  fi
else
  git add .
  git commit -m "Auto-Deploy: $COMMIT_MSG"
  if git push; then
    echo
    echo -e "\033[33m✅ --- Successfully pushed Client to GitHub. ---\033[0m"
  else
    echo
    echo -e "\033[1;31m🛑 --- Failed to push Client to GitHub! ---\033[0m"
  fi
fi
echo

cd $MAIN_PROJECT_DIR
cd server_build
if [ $DO_INIT -eq 1 ]; then
  git init
  git add .
  git commit -m "Auto-Deploy: Init Commit [$TIMESTAMP]"
  git remote add origin $GIT_SERVER_REPO
  git branch -M main
  if git push -u origin main; then
    echo
    echo -e "\033[33m✅ --- Successfully pushed Server to GitHub and linked to remote origin. ---\033[0m"
  else
    echo
    echo -e "\033[1;31m🛑 --- Failed to push Server to GitHub and link to remote origin! ---\033[0m"
  fi
else
  git add .
  git commit -m "Auto-Deploy: $COMMIT_MSG"
  if git push; then
    echo
    echo -e "\033[33m✅ --- Successfully pushed Server to GitHub. ---\033[0m"
  else
    echo
    echo -e "\033[1;31m🛑 --- Failed to push Server to GitHub! ---\033[0m"
  fi
fi
echo
cd $WASP_PROJECT_DIR

echo -e "WASP_WEB_CLIENT_URL=$REACT_APP_API_URL"
echo -e "WASP_SERVER_URL=https://app.server.com"
echo -e "PORT=3001"
echo -e "DATABASE_URL="
echo -e "JWT_SECRET="

# Get the end time and calculate the difference
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

echo
if [ $elapsed_time -gt 59 ]; then
    minutes=$((elapsed_time / 60))
    seconds=$((elapsed_time % 60))
    echo -e "\033[1;33m🤖 --- DEPLOYMENT COMPLETED IN: $minutes minute and $seconds seconds!\033[0m"
else
    echo -e "\033[1;33m🤖 --- DEPLOYMENT COMPLETED IN: $elapsed_time seconds!\033[0m"
fi