# Docker Compose Environment Manager

This repository provides a Bash script, `select-docker-context.sh`, designed to streamline the management of Docker Compose configurations across multiple environments. It enables effortless selection and setup of Docker contexts, host connection strings, and associated environment files, ensuring your Docker Compose configurations remain clean, dynamic, and organized.

---

## Why Use This Script?

Handling multiple Docker environments (e.g., local, staging, production) within development projects often becomes cumbersome. This script addresses these complexities by:

- Allowing you to define Docker environments **per project**, preventing unintended global configuration changes.
- Enabling configuration of Docker contexts, remote hosts, environment variables, and Compose files **only within the active shell session**.
- Ensuring settings are applied strictly to your current session, preserving your broader system configuration.
- Providing a straightforward way to execute `docker compose` commands from **any project directory** through a convenient alias.
- Facilitating easy organization and isolation of configurations for **distinct remote environments**, if desired.

Adopting this method enhances safety, efficiency, and consistency in Docker workflows, especially for projects managing multiple environments.

---

## Features

- Interactive selection of both local and remote Docker contexts, hosts, and environments.
- Support for remote Docker hosts using connection strings or Docker contexts.
- Cross-platform compatibility (Linux, macOS, Windows via WSL/Cygwin).
- Automatic configuration of necessary environment variables for Docker Compose.

---

## Installation

Clone the repository or copy the script `select-docker-context.sh` into your project's scripts directory:

```bash
git clone https://github.com/your-username/docker-compose-env-manager.git
```

---

## Usage

### 1. Create a Configuration File

Prepare a configuration file (e.g., `compose.config`) using the following format:

```bash
config_name=context|environment_path
```

**Example:**

```bash
staging=ssh://root@staging.example.com|./environments/staging
production=my-production-context|./environments/production
```

Each entry specifies a name, a Docker context or host connection string, and a path to an environment-specific directory. This directory can contain a `.env` file to override more general environment variables and may also include Docker Compose YAML files, such as `docker-compose.yml` and `docker-compose.override.yml`.

Ensure that your compose.config file is located in the same directory as your main docker-compose.yml file.

### 2. Run the Script

To apply the selected configuration to your current shell session, source the script as follows:

```bash
source ./scripts/select-docker-context.sh /full/path/to/compose.config
```

The script interactively prompts you to choose your desired environment.

### 3. Configure Docker Compose Alias

Simplify Docker Compose commands by adding this alias to your project's `.bashrc` file:

```bash
alias dc='COMPOSE_ENV_FILES=$COMPOSE_APP_ENV_FILES COMPOSE_FILE=$COMPOSE_APP_FILES docker compose'
```

You can then conveniently run commands like:

```bash
dc up -d
```

from any directory within your project.

### 4. Integration with Visual Studio Code

Since the script is interactive, it is best used within specific contexts, such as a VSCode terminal session.

#### Configure a VSCode Terminal Profile

Add the following profile in your project's `.vscode/settings.json` file:

```json
"terminal.integrated.profiles.windows": {
  "Git Bash (docker)": {
    "source": "Git Bash",
    "args": ["--rcfile", "${workspaceFolder}/.bashrc"]
  }
}
```

#### Project-Specific `.bashrc`

Create a `.bashrc` file at your project's root containing:

```bash
source ./scripts/select-docker-context.sh ./compose.config
```

When opening a VSCode terminal using this profile, the script will automatically prompt for the Docker environment selection.

---

## Example Project Structure

```text
project-root/
├── .vscode/                            # VSCode-specific settings
│   └── settings.json
├── environments/                       # Environment-specific configurations
│   ├── production/
│   │   ├── .env                        # Production-specific environment variables
│   │   └── docker-compose.override.yml # Production-specific Compose overrides
│   └── staging/
│       ├── .env                        # Staging-specific environment variables
│       └── docker-compose.override.yml # Staging-specific Compose overrides
├── scripts/                            # Management scripts
│   └── select-docker-context.sh
├── src/                                # Application source code and related files
├── .bashrc                             # Project-specific Bash configuration for VSCode
├── .env                                # Default environment variables
├── compose.config                      # Environment configuration file
└── docker-compose.yml                  # Main Docker Compose file
```

---

## Environment Variables Set by the Script

| Variable                 | Description                                      |
| ------------------------ | ------------------------------------------------ |
| `DOCKER_APPLICATION_DIR` | Root directory of Docker Compose files           |
| `DOCKER_APPLICATION_ENV` | Path to environment-specific configuration files |
| `DOCKER_CONFIG_NAME`     | Selected configuration name                      |
| `DOCKER_HOST`            | Docker host URL or context                       |
| `COMPOSE_APP_ENV_FILES`  | List of `.env` files used by Docker Compose      |
| `COMPOSE_APP_FILES`      | Docker Compose YAML files to load                |

---

## Enhancing Your Terminal Prompt

To display the active Docker configuration and Git branch directly in your terminal prompt, include the following in your project's `.bashrc`:

```bash
export PS1='\[\e[32m\]$(if [[ "$PWD" == "$DOCKER_APPLICATION_SERVICE_PATH"* ]]; then realpath --relative-to="$DOCKER_APPLICATION_SERVICE_PATH/../" "$PWD"; else echo "$PWD"; fi) \[\e[91m\]($(echo -e "\U1F33F") $(git branch --show-current) | $(echo -e "\U1F433") ${DOCKER_CONFIG_NAME})\[\e[00m\] \$ '
```

This clearly indicates your current working environment, git branch, and selected Docker context.
