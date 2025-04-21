#!/usr/bin/env bash
# USAGE:
#   To run this script and set environment variables in your current shell, run:
#       source ./select-app-context.sh /full/path/to/compose.config
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
  echo "Usage: source $0 /full/path/to/compose.config"
  return 1 2>/dev/null || exit 1
fi

CONFIG_FILE="$1"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: File '$CONFIG_FILE' does not exist."
  return 1 2>/dev/null || exit 1
fi

# read all non-blank, non-comment lines
mapfile -t configs < <(
  grep -E '^[[:space:]]*[^#]' "$CONFIG_FILE" \
    | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//'
)

if (( ${#configs[@]} == 0 )); then
  echo "Error: No configurations found in $CONFIG_FILE"
  return 1 2>/dev/null || exit 1
fi

# extract only names
config_names=()
for line in "${configs[@]}"; do
  config_names+=("${line%%=*}")
done

echo "Select a configuration from $CONFIG_FILE:"
select cfg_name in "${config_names[@]}"; do
  if [[ -n "$env " ]]; then
    # source the helper in "FILE" mode
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$script_dir/set-docker-context.sh" \
      --configs-file "$CONFIG_FILE" --name "$cfg_name"
    break
  else
    echo "Invalid selection. Please try again."
  fi
done
