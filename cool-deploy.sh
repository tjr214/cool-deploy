#!/bin/bash

# Some project variables
WASP_PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PARENT_DIR=$(dirname "$WASP_PROJECT_DIR")
FIRST_TIME_RUN=0
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
# SETUP FILESYSTEM & CONFIGURE DEPLOYMENT VARIABLES
# ------------------------------------------------------------------------------

# Lets make sure we have the directories we need
cd $WASP_PROJECT_DIR
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
else # Configure our `cool-deploy`` script!
  echo -e "\033[1;32m🤖 --- LET'S GET COOL-DEPLOY SET UP! ---\033[0m"
  SETTINGS_CONFIRM=0
  FIRST_TIME_RUN=1
  while [ $SETTINGS_CONFIRM -eq 0 ]; do # Get user inout and configure vars
    echo
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

echo -e "\033[1;36m🤖 --- PROJECT & DEPLOYMENT INFO...\033[0m"
echo

echo -e "\033[1;43m• WASP PROJECT \033[3;43m$WASP_APP_NAME \033[0m"
echo -e "\033[1;33m - Running on Wasp:\033[0m \033[31m$WASP_VERSION\033[0m"
echo -e "\033[1;33m - Project Directory:\033[0m $WASP_PROJECT_DIR"
echo -e "\033[1;33m - Client Directory:\033[0m $CLIENT_DEPLOY_DIR"
echo -e "\033[1;33m - Server Directory:\033[0m $SERVER_DEPLOY_DIR"
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
    echo -e "\033[1;33m🤖 --- DEPLOYMENT COMPLETED IN: $minutes $MINUTE_SUFIX and $seconds seconds!\033[0m"
else
    echo -e "\033[1;33m🤖 --- DEPLOYMENT COMPLETED IN: $elapsed_time seconds!\033[0m"
fi
