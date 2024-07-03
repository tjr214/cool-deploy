#!/bin/bash

# Project path variables
WASP_PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MAIN_PROJECT_DIR=$(dirname "$WASP_PROJECT_DIR")

# Let's go!
echo
echo -e "\033[1;32m🤖 --- CREATING BUILD/DEPLOY DIRECTORIES FOR CLIENT & SERVER... ---\033[0m"
echo

# Get back to the main `project` directory and create the build-deploy directories
cd $MAIN_PROJECT_DIR
if [ ! -d "client_build" ]; then
  mkdir -p "client_build"
  echo -e "\033[33m✅ --- Created client_build/ directory. ---\033[0m"
  echo
else
  echo -e "\033[31m💀 --- Error: client_build/ directory already exists. Please delete it and try again. ---\033[0m"
  echo
  exit 1
fi

if [ ! -d "server_build" ]; then
  mkdir -p "server_build"
  echo -e "\033[33m✅ --- Created server_build/ directory. ---\033[0m"
  echo
else
  echo -e "\033[31m💀 --- Error: server_build/ directory already exists. Please delete it and try again. ---\033[0m"
  echo
  exit 1
fi

# Jump back to the working Wasp project directory
cd $WASP_PROJECT_DIR

echo
echo -e "\033[1;32m🤖 --- LET'S GET COOL-DEPLOY SET UP! ---\033[0m"

SETTINGS_CONFIRM=0
while [ $SETTINGS_CONFIRM -eq 0 ]; do
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

  read -p $'\033[33mWhat port should the server run on? (default 3001):\033[0m ' WASP_SERVER_PORT
  read -p $'\033[33mDatabase URL (or, hit enter to leave blank for now):\033[0m ' WASP_DATABASE_URL
  read -p $'\033[33mJWT Secret Key (or, hit enter to generate):\033[0m ' WASP_JWT_SECRET
  
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

  # Print variables and confirm selections
  echo
  echo -e "\033[1;36m🤖 --- SETTINGS AND ENVIRONMENT CONFIGURATION ---\033[0m"
  echo
  echo -e "\033[1;34mWASP_WEB_CLIENT_URL\033[0m=$REACT_APP_API_URL"
  echo -e "\033[1;34mWASP_SERVER_URL\033[0m=$WASP_SERVER_URL"
  echo -e "\033[1;34mWASP_SERVER_PORT\033[0m=$WASP_SERVER_PORT"
  echo -e "\033[1;34mDATABASE_URL\033[0m=$WASP_DATABASE_URL"
  echo -e "\033[1;34mJWT_SECRET\033[0m=$WASP_JWT_SECRET"
  echo -e "\033[1;34mGIT_CLIENT_REPO\033[0m=$WASP_GIT_CLIENT_REPO"
  echo -e "\033[1;34mGIT_SERVER_REPO\033[0m=$WASP_GIT_SERVER_REPO"
  echo

  while true; do
    read -p $'\033[33mCONFIRM: Would you like to continue with these settings? (y/n):\033[0m ' CONTINUE
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
done

echo
echo -e "\033[33m✅ --- Configured settings for \`cool-deploy.sh\`! ---\033[0m"
echo

echo
echo -e "\033[1;32m🤖 --- DOWNLOADING AND CONFIGURING COOL-DEPLOY...\033[0m"
echo
echo

# Download `cool-deploy.sh` script to the current directory
rm -rf cool-deploy.sh
if (curl -fsSL -o cool-deploy.sh https://github.com/tjr214/cool-deploy/raw/main/cool-deploy.sh); then 
  chmod +x cool-deploy.sh
  echo -e "\033[33m✅ --- Successfully downloaded \`cool-deploy.sh\` script ---\033[0m"
  echo
else
  echo
  echo -e "\033[31m🛑 --- Failed to download \`cool-deploy.sh\`! See above for errors... ---\033[0m"
  exit 1
fi

# Download `template.coolify.env` file to the current directory
if (curl -fsSL -o .env.coolify https://github.com/tjr214/cool-deploy/raw/main/template.coolify.env); then 
  echo -e "\033[33m✅ --- Successfully downloaded Coolify Environment Template file ---\033[0m"
  echo
else
  echo
  echo -e "\033[31m🛑 --- Failed to download \`template.coolify.env\`! See above for errors... ---\033[0m"
  exit 1
fi

# Replace the placeholders in `.coolify.env`
if (sed -i "" "s|{{FRONT_URL}}|$REACT_APP_API_URL|g; s|{{BACK_URL}}|$WASP_SERVER_URL|g; s|{{BACK_PORT}}|$WASP_SERVER_PORT|g; s|{{DATABASE_URL}}|$WASP_DATABASE_URL|g; s|{{AUTH_SECRET}}|$WASP_JWT_SECRET|g; s|{{GIT_CLIENT_URL}}|$WASP_GIT_CLIENT_REPO|g; s|{{GIT_SERVER_URL}}|$WASP_GIT_SERVER_REPO|g" .env.coolify); then 
  echo -e "\033[33m✅ --- Successfully configured Coolify Environment with your chosen settings ---\033[0m"
  echo
else
  echo
  echo -e "\033[31m🛑 --- Failed to configure Coolify Environment file! See above for errors... ---\033[0m"
  echo
  exit 1
fi

# Let's make sure we add the Coolify Environemnt file to `.gitignore`
if ! grep -q -z -E ".env\.coolify" .gitignore; then
  echo "" >> .gitignore
  echo "# Ignore the Coolify environment file." >> .gitignore
  echo "# This file is just for you (or the admin) and does not belong in a Git Repo!" >> .gitignore
  echo ".env.coolify" >> .gitignore
  echo -e "\033[33m✅ ---  Updated \`.gitignore\` to be aware of the Coolify Environment file ---\033[0m"
else
  echo -e "\033[33m✅ --- \`.gitignore\` is alread aware of the Coolify Environment file ---\033[0m"
fi
echo

# Check if a .env.server file exists, if not, create one
if [ ! -e .env.server ]; then
  touch .env.server
  echo -e "\033[33m✅ --- Created a new .env.server file ---\033[0m"
  echo
fi

if ! grep -q -z -E "DATABASE_URL" .env.server; then
  echo "# Database URL (uncomment when ready to deploy to Coolify)" >> .env.server
  echo "# DATABASE_URL=$WASP_DATABASE_URL" >> .env.server
  echo -e "\033[33m✅ --- Added DATABASE_URL to \`.env.server\` ---\033[0m"
else
  echo -e "\033[33m✅ --- \`.env.server\` already has DATABASE_URL ---\033[0m"
fi

echo
echo
echo -e "\033[1;32m🤖 --- PERFORMING INITIAL COMMIT ON GIT REPOS...\033[0m"
echo

# Perform initial git commit on the client repo
cd $MAIN_PROJECT_DIR
cd client_build
git init
touch README.md && echo "# Client Build" > README.md
git add .
git commit -m "Cool-Deploy Setup: Init Commit [$TIMESTAMP]"
git remote add origin $GIT_CLIENT_REPO
git branch -M main
if git push -u origin main; then
  echo
  echo -e "\033[33m✅ --- Successfully pushed Client to GitHub and linked to remote origin. ---\033[0m"
else
  echo
  echo -e "\033[1;31m🛑 --- Failed to push Client to GitHub and link to remote origin! ---\033[0m"
fi

# Perform initial git commit on the server repo
cd $MAIN_PROJECT_DIR
cd server_build
git init
touch README.md && echo "# Server Build" > README.md
git add .
git commit -m "Cool-Deploy Setup: Init Commit [$TIMESTAMP]"
git remote add origin $GIT_SERVER_REPO
git branch -M main
if git push -u origin main; then
  echo
  echo -e "\033[33m✅ --- Successfully pushed Server to GitHub and linked to remote origin. ---\033[0m"
else
  echo
  echo -e "\033[1;31m🛑 --- Failed to push Server to GitHub and link to remote origin! ---\033[0m"
fi

# Clean up and exit
echo
echo
echo -e "\033[1;32m🤖 --- CLEANING UP AND EXITING CLEANLY...\033[0m"
echo

# Print ready-to-deploy message
echo
echo -e "\033[1;33mWHEN READY TO DEPLOY:\033[0m"
echo -e "\033[33m- Uncomment the DATABASE_URL line in \`.env.server\`.\033[0m"
echo -e "\033[33m- Make sure the env variables in \`.env.coolify\` are added to the Coolfy project.\033[0m"
echo -e "\033[33m- Add the following to your \`main.wasp\` file:\033[0m
\033[35mapp\033[0m yourWaspApp \033[33m{\033[0m
  [...]
  db\033[36m:\033[0m \033[31m{\033[0m
    system\033[36m:\033[0m \033[31mPostgreSQL\033[36m,\033[0m
  \033[35m}\033[36m,\033[0m
\033[31m}\033[0m"
echo -e "\033[33m- Run \`./cool-deploy.sh\` to deploy the project.\033[0m"
echo -e "\033[33m- And Profit!\033[0m"
echo

# Delete the setup script
rm -rf setup.sh
echo "ALL DONE! 🎉"
echo
