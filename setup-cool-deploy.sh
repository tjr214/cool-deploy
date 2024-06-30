#!/bin/bash

echo
echo -e "\033[1;32m🤖 --- LET'S GET COOL-DEPLOY SET UP...\033[0m"

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
  echo -e "\033[1;36m🤖 --- PROJECT SETTINGS...\033[0m"
  echo
  echo -e "WASP_WEB_CLIENT_URL=$REACT_APP_API_URL"
  echo -e "WASP_SERVER_URL=$WASP_SERVER_URL"
  echo -e "PORT=$WASP_SERVER_PORT"
  echo -e "DATABASE_URL=$WASP_DATABASE_URL"
  echo -e "JWT_SECRET=$WASP_JWT_SECRET"

  echo -e "GIT_CLIENT_REPO=$WASP_GIT_CLIENT_REPO"
  echo -e "GIT_SERVER_REPO=$WASP_GIT_SERVER_REPO"
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

  echo
  echo -e "\033[31m🛑 --- Settings not configured! Trying again... ---\033[0m"
done

echo
echo -e "\033[33m✅ --- Configured settings for \`cool-deploy.sh\`! ---\033[0m"
echo

echo -e "\033[1;32m🤖 --- DOWNLOADING AND CONFIGURING COOL-DEPLOY...\033[0m"
echo

# # Download `cool-deploy.sh` script to the current directory
# if (curl -fsSL -o cool-deploy.sh https://github.com/tjr214/cool-deploy/raw/main/setup-cool-deploy.sh); then 
#   chmod +x cool-deploy.sh
#   echo -e "\033[33m✅ --- Successfully downloaded \`cool-deploy.sh\` script ---\033[0m"
#   echo
# else
#   echo "🛑 --- Failed to download \`cool-deploy.sh\`! See above for errors... ---\033[0m"
#   exit 1
# fi

# # Download `template.coolify.env` file to the current directory
# if (curl -fsSL -o .coolify.env https://github.com/tjr214/cool-deploy/raw/main/template.coolify.env); then 
#   echo -e "\033[33m✅ --- Successfully downloaded Coolify Environment Template file ---\033[0m"
#   echo
# else
#   echo "🛑 --- Failed to download \`template.coolify.env\`! See above for errors... ---\033[0m"
#   exit 1
# fi

# Replace the placeholders in `.coolify.env`
if (sed -i "" "s|{{FRONT_URL}}|$REACT_APP_API_URL|g; s|{{BACK_URL}}|$WASP_SERVER_URL|g; s|{{BACK_PORT}}|$WASP_SERVER_PORT|g; s|{{DATABASE_URL}}|$WASP_DATABASE_URL|g; s|{{AUTH_SECRET}}|$WASP_JWT_SECRET|g; s|{{GIT_CLIENT_URL}}|$WASP_GIT_CLIENT_REPO|g; s|{{GIT_SERVER_URL}}|$WASP_GIT_SERVER_REPO|g" .coolify.env); then 
  echo -e "\033[33m✅ --- Successfully configured Coolify Environment with your chosen settings ---\033[0m"
  echo
else
  echo "🛑 --- Failed to configure Coolify Environment file! See above for errors... ---\033[0m"
  echo
  exit 1
fi

# Let's make sure we add the Coolify Environemnt file to `.gitignore`
if ! grep -q -z -E ".coolify\.env" .gitignore; then
  echo "" >> .gitignore
  echo "# Ignore the Coolify environment file." >> .gitignore
  echo "# This file is just for you (or the admin) and does not belong in a Git Repo!" >> .gitignore
  echo ".coolify.env" >> .gitignore
  echo -e "\033[33m✅ ---  Updated \`.gitignore\` to be aware of the Coolify Environment file ---\033[0m"
else
  echo -e "\033[33m✅ --- \`.gitignore\` is alread aware of the Coolify Environment file ---\033[0m"
fi

echo
echo -e "\033[1;32m🤖 --- RUNNING INITIAL BUILD, GIT COMMIT AND PUSH...\033[0m"

# Run Initial Deployment!
if (./cool-deploy.sh); then
  echo
  echo -e "\033[1;32m🤖 --- CLEANING UP AND EXITING CLEANLY...\033[0m"
  echo
  echo "ALL DONE! 🎉"
else
  echo
  echo -e "\033[1;31m🛑 --- COOL-DEPLOY FAILED! See above for details... CLEANING UP AND EXITING. ---\033[0m"
  echo
fi

# Delete the setup script
# rm -rf setup.sh
