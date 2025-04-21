#!/usr/bin/env bash
# USAGE:
#   Mode 1 (using a configuration file):
#     source ./set-docker-context.sh --configs-file /path/to/compose.config --name <config_name>
#
#   Mode 2 (manual parameters):
#     source ./set-docker-context.sh --endpoint <docker_endpoint> --base <base_dir> --overrides <overrides_dir> --name <config_name>

# Helper: print usage and exit
usage() {
  echo "Usage:"
  echo "  Mode 1 (configs file): source $0 --configs-file <path> --name <config_name>"
  echo "  Mode 2 (manual):       source $0 --endpoint <endpoint_address> --base <base_dir> --overrides <overrides_dir> --name <config_name>"
  exit 1
}

# Parse arguments
MODE=""
CONFIGS_FILE=""
ENDPOINT=""
BASE_DIR=""
OVERRIDES_DIR=""
CONFIG_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configs-file)
      CONFIGS_FILE="$2"
      shift 2
      ;;
    --endpoint)
      ENDPOINT="$2"
      shift 2
      ;;
    --base)
      BASE_DIR="$2"
      shift 2
      ;;
    --overrides)
      OVERRIDES_DIR="$2"
      shift 2
      ;;
    --name)
      CONFIG_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [[ -z "$CONFIG_NAME" ]]; then
  echo "Error: --name is required."
  usage
fi

# Identify mode: Mode1 uses configs file; Mode2 uses endpoint
if [[ -n "$CONFIGS_FILE" ]]; then
  MODE="FILE"
elif [[ -n "$ENDPOINT" && -n "$BASE_DIR" && -n "$OVERRIDES_DIR" ]]; then
  MODE="MANUAL"
else
  echo "Error: Invalid combination of parameters."
  usage
fi

# Determine OS type
os_type=''
case "$(uname -s)" in
    Linux*)               os_type='Linux';;
    Darwin*)              os_type='Mac';;
    CYGWIN*|MINGW*|MSYS*) os_type='Windows';;
    *)                    os_type='Unknown';;
esac

# Function to get the absolute path
get_abs_path() {
  local file="$1"
  local resolved
  resolved="$(realpath "$file")"
  if [[ "$os_type" == "Windows" ]]; then
    cygpath -w "$resolved"
  else
    echo "$resolved"
  fi
}

if [[ "$MODE" == "FILE" ]]; then
  if [[ ! -f "$CONFIGS_FILE" ]]; then
    echo "Error: File '$CONFIGS_FILE' does not exist."
    return 1 2>/dev/null || exit 1
  fi

  ABS_CONFIG_DIR=$(dirname "$(realpath "$CONFIGS_FILE")")
  
  # Read config file lines, ignoring blanks and comments, and look for the matching config name.
  config_line=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -z "$line" || "$line" == \#* ]] && continue
    # Get the config name from the line
    name_on_line="${line%%=*}"
    if [[ "$name_on_line" == "$CONFIG_NAME" ]]; then
      config_line="$line"
      break
    fi
  done < "$CONFIGS_FILE"
  
  if [[ -z "$config_line" ]]; then
    echo "Error: Configuration with name '$CONFIG_NAME' not found in $CONFIGS_FILE"
    return 1 2>/dev/null || exit 1
  fi

  DOCKER_CONFIG_NAME="$CONFIG_NAME"
  rest="${config_line#*=}"
  context="${rest%%|*}"
  env_path="${rest#*|}"

  # Calculate abs_env_path: if relative then based on ABS_CONFIG_DIR.
  if [[ "$env_path" != /* ]]; then
    abs_env_path=$(realpath "$ABS_CONFIG_DIR/$env_path")
  else
    abs_env_path=$(realpath "$env_path")
  fi
  DOCKER_APPLICATION_DIR="$ABS_CONFIG_DIR"
  DOCKER_APPLICATION_ENV="$abs_env_path"

  # Set DOCKER_HOST: if context is a connection string, use it directly.
  if [[ "$context" == *"://"* ]]; then
    DOCKER_HOST="$context"
    echo -e "Docker endpoint: $DOCKER_HOST\r\n"
  else
    echo "Verifying Docker context: $context ..."
    host_value=$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}' 2>/dev/null)
    if [[ -z "$host_value" ]]; then
      echo "Error: Unable to retrieve host for Docker context '$context'"
      return 1 2>/dev/null || exit 1
    fi
    DOCKER_HOST="$host_value"
    echo "Using Docker context '$context' with host: $DOCKER_HOST"
  fi

elif [[ "$MODE" == "MANUAL" ]]; then
  # Mode 2: use manual parameters
  DOCKER_CONFIG_NAME="$CONFIG_NAME"
  DOCKER_HOST="$ENDPOINT"
  # Resolve base and overrides directories
  DOCKER_APPLICATION_DIR=$(realpath "$BASE_DIR")
  DOCKER_APPLICATION_ENV=$(realpath "$OVERRIDES_DIR")
  echo "Using manual parameters for Docker host: $DOCKER_HOST"
fi

# Set COMPOSE_PATH_SEPARATOR based on OS
if [[ "$os_type" == "Windows" ]]; then
  COMPOSE_PATH_SEPARATOR=";"
else
  COMPOSE_PATH_SEPARATOR=":"
fi

################################ COMPOSE_APP_ENV_FILES
env_files=(
  "$DOCKER_APPLICATION_DIR/.env" 
  # Adding the same file multiple times to make env resolve vars that reference other vars in the same file
  "$DOCKER_APPLICATION_ENV/.env" 
  "$DOCKER_APPLICATION_ENV/.env" 
  "$DOCKER_APPLICATION_ENV/.env" 
  "$DOCKER_APPLICATION_ENV/.env" 
  "$DOCKER_APPLICATION_ENV/.env" 
)
COMPOSE_APP_ENV_FILES=""
for env_file in "${env_files[@]}"; do
  if [[ -f "$env_file" ]]; then
    COMPOSE_APP_ENV_FILES+=$(get_abs_path "$env_file"),
  fi
done
# Remove trailing comma if present
COMPOSE_APP_ENV_FILES="${COMPOSE_APP_ENV_FILES%,}"

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
for file in "${config_files[@]}"; do
  if [[ -f "$file" ]]; then
    COMPOSE_APP_FILES+=$(get_abs_path "$file")$COMPOSE_PATH_SEPARATOR
  fi
done
COMPOSE_APP_FILES="${COMPOSE_APP_FILES%$COMPOSE_PATH_SEPARATOR}"

# Export the variables
export COMPOSE_APP_FILES
export COMPOSE_APP_ENV_FILES
export COMPOSE_PATH_SEPARATOR
export DOCKER_HOST
export DOCKER_APPLICATION_DIR
export DOCKER_CONFIG_NAME
export DOCKER_APPLICATION_ENV
