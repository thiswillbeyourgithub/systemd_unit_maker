#!/bin/zsh

# Enable for debugging
# set -x
#
# systemd_unit_maker.sh - Creates systemd service and timer units from a command
#
# Usage:
#   ./systemd_unit_maker.sh [--user|--system] --name UNIT_NAME --command "COMMAND" 
#                           [--description "DESCRIPTION"] [--frequency "FREQUENCY"] [--enable]
#
# Options:
#   --user          Install for current user (default)
#   --system        Install system-wide (requires root)
#   --name          Name for the systemd unit
#   --command       Command to run in the service
#   --description   Description of the service (optional)
#   --frequency     Timer frequency (e.g. "daily" or "1h") (optional, default "1d")
#   --enable        Enable and start the timer after creation (default: false)
#
# Example:
#   ./systemd_unit_maker.sh --user --name backup_home --command "tar -czf /tmp/backup.tar.gz /home/user" 
#                          --description "Daily home backup" --frequency "1d"

# Exit on error
set -e

# Default values
user_mode=true
unit_name=""
command=""
description="Systemd service created by systemd_unit_maker.sh"
frequency="1d"
enable=false

echo "=== Starting systemd unit maker ==="

# Function to print usage information
print_help() {
  cat << EOF
systemd_unit_maker.sh - Creates systemd service and timer units from a command

Usage:
  ./systemd_unit_maker.sh [--user|--system] --name UNIT_NAME --command "COMMAND" 
                         [--description "DESCRIPTION"] [--frequency "FREQUENCY"] [--enable]

Options:
  --help, -h      Show this help message and exit
  --user          Install for current user (default)
  --system        Install system-wide (requires root)
  --name          Name for the systemd unit
  --command       Command to run in the service
  --description   Description of the service (optional)
  --frequency     Timer frequency (e.g. "daily" or "1h") (optional, default "1d")
  --enable        Enable and start the timer after creation (default: false)

Example:
  ./systemd_unit_maker.sh --user --name backup_home --command "tar -czf /tmp/backup.tar.gz /home/user" \\
                         --description "Daily home backup" --frequency "1d"
EOF
}

# Parse arguments
echo "Parsing command line arguments..."
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      print_help
      exit 0
      ;;
    --user)
      user_mode=true
      shift
      ;;
    --system)
      user_mode=false
      shift
      ;;
    --name)
      unit_name="$2"
      shift 2
      ;;
    --command)
      command="$2"
      shift 2
      ;;
    --description)
      description="$2"
      shift 2
      ;;
    --frequency)
      frequency="$2"
      shift 2
      ;;
    --enable)
      enable=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Display configuration summary
echo "=== Configuration Summary ==="
echo "Installation mode: $(if $user_mode; then echo "User"; else echo "System"; fi)"
echo "Unit name: $unit_name"
echo "Command: $command"
echo "Description: $description"
echo "Timer frequency: $frequency"
echo "Enable after creation: $(if $enable; then echo "Yes"; else echo "No"; fi)"
echo "=========================="

# Validate required arguments
if [[ -z "$unit_name" ]]; then
  echo "Error: Unit name is required (--name)"
  exit 1
fi

if [[ -z "$command" ]]; then
  echo "Error: Command is required (--command)"
  exit 1
fi

# Replace spaces with underscores in unit name
unit_name=${unit_name// /_}

# Determine systemd directory based on user/system mode
if $user_mode; then
  systemd_dir="$HOME/.config/systemd/user"
  alias systemctl_cmd="systemctl --user"
  echo "Using user mode: Units will be installed to $systemd_dir"
else
  systemd_dir="/etc/systemd/system"
  alias systemctl_cmd="sudo systemctl"
  echo "Using system mode: Units will be installed to $systemd_dir"
fi

# Create systemd directory if it doesn't exist
echo "Creating systemd directory if it doesn't exist: $systemd_dir"
mkdir -p "$systemd_dir"
echo "Systemd directory ready"

# Get the directory of this script
script_dir="$(dirname "$0")"

# Service and timer file paths
service_file="$systemd_dir/${unit_name}.service"
timer_file="$systemd_dir/${unit_name}.timer"
echo "Service file will be created at: $service_file"
echo "Timer file will be created at: $timer_file"

# Copy template files
echo "Copying template files..."
if $user_mode; then
  echo "Using templates: $script_dir/templates/default.service and $script_dir/templates/default.timer"
  cp "$script_dir/templates/default.service" "$service_file"
  cp "$script_dir/templates/default.timer" "$timer_file"
else
  echo "Using templates with sudo: $script_dir/templates/default.service and $script_dir/templates/default.timer"
  sudo cp "$script_dir/templates/default.service" "$service_file"
  sudo cp "$script_dir/templates/default.timer" "$timer_file"
fi
echo "Template files copied successfully"

# Replace placeholders in the service file
echo "Configuring service file..."
if $user_mode; then
  sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$service_file"
  sed -i "s|\[\[COMMAND\]\]|$command|g" "$service_file"
else
  sudo sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$service_file"
  sudo sed -i "s|\[\[COMMAND\]\]|$command|g" "$service_file"
fi

echo "Service file configured successfully"

# Replace placeholders in the timer file
echo "Configuring timer file..."
if $user_mode; then
  sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$timer_file"
  sed -i "s/\[\[FREQUENCY\]\]/$frequency/g" "$timer_file"
  sed -i "s/\[\[UNIT_NAME\]\]/$unit_name/g" "$timer_file"
else
  sudo sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$timer_file"
  sudo sed -i "s/\[\[FREQUENCY\]\]/$frequency/g" "$timer_file"
  sudo sed -i "s/\[\[UNIT_NAME\]\]/$unit_name/g" "$timer_file"
fi

echo "Timer file configured successfully"

# Reload systemd daemon
echo "Reloading systemd daemon..."
systemctl_cmd daemon-reload
echo "Systemd daemon reloaded"

echo "Systemd units created successfully:"
echo "  Service: $service_file"
echo "  Timer: $timer_file"
echo ""

if $enable; then
  # Start and enable the timer
  echo "Enabling and starting timer: ${unit_name}.timer"
  systemctl_cmd enable --now "${unit_name}.timer"
  echo "Timer enabled and started successfully"

  echo "Timer enabled and started. You can check its status with:"
  echo "  systemctl_cmd status ${unit_name}.timer"
else
  echo "Units created but not enabled. To enable and start the timer, run:"
  echo "  systemctl$(if $user_mode; then echo " --user"; fi) enable --now ${unit_name}.timer"
fi

unalias systemctl_cmd
