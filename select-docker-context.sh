#!/usr/bin/env bash
# USAGE:
#   To run this script and set environment variables in your current shell, run:
#       source ./select-docker-context.sh /full/path/to/compose.config
#
# The script expects a path to the config file (e.g., /path/to/compose.config)
# and uses the folder containing that file as the main docker application folder.
#
# Expected file format per line is:
#   <config_name>=<context>|<environment_path>
#
# Example:
#   staging=ssh://root@staging.example.com|./env
#   production=my-production-context|/var/docker/prod-env

if [ -z "$1" ]; then
  echo "Usage: source ./select-docker-context.sh /full/path/to/compose.config"
  return 1 2>/dev/null || exit 1
fi

CONFIG_FILE="$1"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: File '$CONFIG_FILE' does not exist."
  return 1 2>/dev/null || exit 1
fi

os_type='';
case "$(uname -s)" in
    Linux*)               os_type='Linux';;
    Darwin*)              os_type='Mac';;
    CYGWIN*|MINGW*|MSYS*) os_type='Windows';;
    *)                    os_type='Unknown';;
esac

# Function that returns the absolute path:
get_abs_path() {
  local file="$1"
  # First, resolve the full path using realpath
  local resolved
  resolved="$(realpath "$file")"
  if [[ "$os_type" == "Windows" ]]; then
    cygpath -w "$resolved"
  else
    echo "$resolved"
  fi
}

ABS_CONFIG_DIR=$(dirname "$(realpath "$CONFIG_FILE")")

configs=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -z "$line" || "$line" == \#* ]] && continue
  configs+=("$line")
done < "$CONFIG_FILE"

if [[ ${#configs[@]} -eq 0 ]]; then
  echo "Error: No configurations found in $CONFIG_FILE"
  return 1 2>/dev/null || exit 1
fi

# Create an array containing only configuration names
config_names=()
for config_line in "${configs[@]}"; do
  config_names+=("${config_line%%=*}")
done

echo "Select a configuration from $CONFIG_FILE:"
select choice in "${config_names[@]}"; do
  if [[ -n "$choice" ]]; then
    # Use the user's selection index (REPLY) to get the full config line
    config_line="${configs[$((REPLY-1))]}"
    
    config_name="${config_line%%=*}"
    rest="${config_line#*=}"
    context="${rest%%|*}"
    env_path="${rest#*|}"
    
    if [[ "$env_path" != /* ]]; then
      abs_env_path=$(realpath "$ABS_CONFIG_DIR/$env_path")
    else
      abs_env_path=$(realpath "$env_path")
    fi

    export DOCKER_APPLICATION_DIR="$ABS_CONFIG_DIR"
    export DOCKER_CONFIG_NAME="$config_name"
    export DOCKER_APPLICATION_ENV="$abs_env_path"
    
    if [[ "$context" == *"://"* ]]; then
      export DOCKER_HOST="$context"
      echo "Using connection string for Docker: $DOCKER_HOST"
    else
      echo "Verifying Docker context: $context ..."
      host_value=$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}' 2>/dev/null)
      if [[ -z "$host_value" ]]; then
        echo "Error: Unable to retrieve host for Docker context '$context'"
        return 1 2>/dev/null || exit 1
      fi
      export DOCKER_HOST="$host_value"
      echo "Using Docker context '$context' with host: $DOCKER_HOST"
    fi

    # set according to if on windows or not
    export COMPOSE_PATH_SEPARATOR=$(if [[ "$os_type" == "Windows" ]]; then echo ";" ; else echo ":" ; fi)

    ################################ COMPOSE_APP_ENV_FILES 
    env_files=(
      "$DOCKER_APPLICATION_DIR/.env" 
      "$DOCKER_APPLICATION_ENV/.env" 
    )
    COMPOSE_APP_ENV_FILES=""
    for env_file in "${env_files[@]}"; do
      if [[ -f "$env_file" ]]; then
        COMPOSE_APP_ENV_FILES+=$(get_abs_path "$env_file"),
      fi
    done
    # Remove the trailing comma
    COMPOSE_APP_ENV_FILES="${COMPOSE_APP_ENV_FILES%,}"
    export COMPOSE_APP_ENV_FILES

    ################################ COMPOSE_APP_FILES
    config_files=(
      "$DOCKER_APPLICATION_DIR/docker-compose.yaml"
      "$DOCKER_APPLICATION_DIR/docker-compose.yml"
      "$DOCKER_APPLICATION_DIR/docker-compose.override.yaml"
      "$DOCKER_APPLICATION_DIR/docker-compose.override.yml"
      "$DOCKER_APPLICATION_ENV/docker-compose.yaml"
      "$DOCKER_APPLICATION_ENV/docker-compose.yml"
      "$DOCKER_APPLICATION_ENV/docker-compose.override.yaml"
      "$DOCKER_APPLICATION_ENV/docker-compose.override.yml"
    )
    COMPOSE_APP_FILES=""
    for config_file in "${config_files[@]}"; do
      if [[ -f "$config_file" ]]; then
        COMPOSE_APP_FILES+=$(get_abs_path "$config_file")$COMPOSE_PATH_SEPARATOR
      fi
    done
    # Remove the trailing separator
    COMPOSE_APP_FILES="${COMPOSE_APP_FILES%$COMPOSE_PATH_SEPARATOR}"
    export COMPOSE_APP_FILES

    echo "Configuration selected:"
    echo "  DOCKER_APPLICATION_DIR = ${DOCKER_APPLICATION_DIR}"
    echo "  DOCKER_CONFIG_NAME     = ${DOCKER_CONFIG_NAME}"
    echo "  DOCKER_APPLICATION_ENV = ${DOCKER_APPLICATION_ENV}"
    echo "  DOCKER_HOST            = ${DOCKER_HOST}"
    echo "  COMPOSE_APP_ENV_FILES  = ${COMPOSE_APP_ENV_FILES}"
    echo "  COMPOSE_APP_FILES      = ${COMPOSE_APP_FILES}"
    break
  else
    echo "Invalid selection. Please try again."
  fi
done
