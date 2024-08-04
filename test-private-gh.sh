#!/bin/bash

source .env.coolify

# Set required parameters
project_uuid="a484kkc"
server_uuid="j484wks"
environment_name="production"
github_app_uuid="zgg8c48"
git_repository="tjr214/wasp-todo-demo-app"
git_branch="main"
ports_exposes="80"
build_pack="static"
description="This is a cool fucking frontend"
domains="https://test.thetjr.com"
base_directory="/"
publish_directory="/deploy/client"
instant_deploy="true"

# Set other parameters to empty strings or defaults
git_commit_sha="HEAD"
# docker_registry_image_name=""
# docker_registry_image_tag=""
# install_command=""
# build_command=""
# start_command=""
# ports_mappings=""
# health_check_enabled="false"
# health_check_path=""
# health_check_port=""
# health_check_host=""
# health_check_method=""
# health_check_return_code=0
# health_check_scheme=""
# health_check_response_text=""
# health_check_interval=0
# health_check_timeout=0
# health_check_retries=0
# health_check_start_period=0
# limits_memory=""
# limits_memory_swap=""
# limits_memory_swappiness=0
# limits_memory_reservation=""
# limits_cpus=""
# limits_cpuset=""
# limits_cpu_shares=0
# custom_labels=""
# custom_docker_run_options=""
# post_deployment_command=""
# post_deployment_command_container=""
# pre_deployment_command=""
# pre_deployment_command_container=""
# manual_webhook_secret_github=""
# manual_webhook_secret_gitlab=""
# manual_webhook_secret_bitbucket=""
# manual_webhook_secret_gitea=""
# redirect=""
# docker_compose_location=""
# docker_compose_raw=""
# docker_compose_custom_start_command=""
# docker_compose_custom_build_command=""
# docker_compose_domains='[""]'
# watch_paths=""

# Create JSON payload
# payload=$(cat <<EOF
# {
#   "project_uuid": "$project_uuid",
#   "server_uuid": "$server_uuid",
#   "environment_name": "$environment_name",
#   "github_app_uuid": "$github_app_uuid",
#   "git_repository": "$git_repository",
#   "git_branch": "$git_branch",
#   "ports_exposes": "$ports_exposes",
#   "build_pack": "$build_pack",
#   "name": "$name",
#   "description": "$description",
#   "domains": "$domains",
#   "is_static": $is_static,
#   "base_directory": "$base_directory",
#   "publish_directory": "$publish_directory",
#   "instant_deploy": $instant_deploy,
#   "dockerfile": "$dockerfile",
#   "git_commit_sha": "$git_commit_sha",
#   "docker_registry_image_name": "$docker_registry_image_name",
#   "docker_registry_image_tag": "$docker_registry_image_tag",
#   "install_command": "$install_command",
#   "build_command": "$build_command",
#   "start_command": "$start_command",
#   "ports_mappings": "$ports_mappings",
#   "health_check_enabled": $health_check_enabled,
#   "health_check_path": "$health_check_path",
#   "health_check_port": "$health_check_port",
#   "health_check_host": "$health_check_host",
#   "health_check_method": "$health_check_method",
#   "health_check_return_code": $health_check_return_code,
#   "health_check_scheme": "$health_check_scheme",
#   "health_check_response_text": "$health_check_response_text",
#   "health_check_interval": $health_check_interval,
#   "health_check_timeout": $health_check_timeout,
#   "health_check_retries": $health_check_retries,
#   "health_check_start_period": $health_check_start_period,
#   "limits_memory": "$limits_memory",
#   "limits_memory_swap": "$limits_memory_swap",
#   "limits_memory_swappiness": $limits_memory_swappiness,
#   "limits_memory_reservation": "$limits_memory_reservation",
#   "limits_cpus": "$limits_cpus",
#   "limits_cpuset": "$limits_cpuset",
#   "limits_cpu_shares": $limits_cpu_shares,
#   "custom_labels": "$custom_labels",
#   "custom_docker_run_options": "$custom_docker_run_options",
#   "post_deployment_command": "$post_deployment_command",
#   "post_deployment_command_container": "$post_deployment_command_container",
#   "pre_deployment_command": "$pre_deployment_command",
#   "pre_deployment_command_container": "$pre_deployment_command_container",
#   "manual_webhook_secret_github": "$manual_webhook_secret_github",
#   "manual_webhook_secret_gitlab": "$manual_webhook_secret_gitlab",
#   "manual_webhook_secret_bitbucket": "$manual_webhook_secret_bitbucket",
#   "manual_webhook_secret_gitea": "$manual_webhook_secret_gitea",
#   "redirect": "$redirect",
#   "docker_compose_location": "$docker_compose_location",
#   "docker_compose_raw": "$docker_compose_raw",
#   "docker_compose_custom_start_command": "$docker_compose_custom_start_command",
#   "docker_compose_custom_build_command": "$docker_compose_custom_build_command",
#   "docker_compose_domains": $docker_compose_domains,
#   "watch_paths": "$watch_paths"
# }
# EOF
# )

client_payload=$(cat <<EOF
{
  "project_uuid": "$project_uuid",
  "server_uuid": "$server_uuid",
  "environment_name": "$environment_name",
  "github_app_uuid": "$github_app_uuid",
  "git_repository": "$git_repository",
  "git_branch": "$git_branch",
  "git_commit_sha": "$git_commit_sha",
  "ports_exposes": "$ports_exposes",
  "build_pack": "$build_pack",
  "description": "$description",
  "domains": "$domains",
  "base_directory": "$base_directory",
  "publish_directory": "$publish_directory",
  "instant_deploy": $instant_deploy
  }
EOF
)

BEARER="Authorization: Bearer $COOLIFY_API_KEY"

# sec_key=$(curl -s --request GET \
#   --url $COOLIFY_BASE_URL/api/v1/security/keys/$github_app_uuid \
#   --header "$BEARER")

# echo "$sec_key"


# res=$(curl -s --request GET \
#   --url $COOLIFY_BASE_URL/api/v1/applications \
#   --header "$BEARER")

# echo "$res" | jq .


# Call cURL with the payload
coolify_client_return=$(curl -s --request POST \
  --url $COOLIFY_BASE_URL/api/v1/applications/private-github-app \
  --header "$BEARER" \
  --header 'Content-Type: application/json' \
  -d "$client_payload")

echo "$coolify_client_return" | jq .

