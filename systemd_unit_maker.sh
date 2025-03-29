#!/bin/zsh
#
# systemd_unit_maker.sh - Creates systemd service and timer units from a command
#
# Usage:
#   ./systemd_unit_maker.sh [--user|--system] --name UNIT_NAME --command "COMMAND" 
#                           [--description "DESCRIPTION"] [--frequency "FREQUENCY"]
#
# Options:
#   --user          Install for current user (default)
#   --system        Install system-wide (requires root)
#   --name          Name for the systemd unit
#   --command       Command to run in the service
#   --description   Description of the service (optional)
#   --frequency     Timer frequency (e.g. "daily" or "1h") (optional, default "1d")
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

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
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
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

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
  systemctl_cmd="systemctl --user"
else
  systemd_dir="/etc/systemd/system"
  systemctl_cmd="sudo systemctl"
fi

# Create systemd directory if it doesn't exist
mkdir -p "$systemd_dir"

# Get the directory of this script
script_dir="$(dirname "$0")"

# Service and timer file paths
service_file="$systemd_dir/${unit_name}.service"
timer_file="$systemd_dir/${unit_name}.timer"

# Copy template files
if $user_mode; then
  cp "$script_dir/templates/default.service" "$service_file"
  cp "$script_dir/templates/default.timer" "$timer_file"
else
  sudo cp "$script_dir/templates/default.service" "$service_file"
  sudo cp "$script_dir/templates/default.timer" "$timer_file"
fi

# Replace placeholders in the service file
if $user_mode; then
  sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$service_file"
  sed -i "s|\[\[COMMAND\]\]|$command|g" "$service_file"
else
  sudo sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$service_file"
  sudo sed -i "s|\[\[COMMAND\]\]|$command|g" "$service_file"
fi

# Replace placeholders in the timer file
if $user_mode; then
  sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$timer_file"
  sed -i "s/\[\[FREQUENCY\]\]/$frequency/g" "$timer_file"
  sed -i "s/\[\[UNIT_NAME\]\]/$unit_name/g" "$timer_file"
else
  sudo sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$timer_file"
  sudo sed -i "s/\[\[FREQUENCY\]\]/$frequency/g" "$timer_file"
  sudo sed -i "s/\[\[UNIT_NAME\]\]/$unit_name/g" "$timer_file"
fi

# Reload systemd daemon
$systemctl_cmd daemon-reload

echo "Systemd units created successfully:"
echo "  Service: $service_file"
echo "  Timer: $timer_file"
echo ""
echo "Press Enter to start and enable the timer, or Ctrl+C to cancel..."
read

# Start and enable the timer
$systemctl_cmd enable --now "${unit_name}.timer"

echo "Timer enabled and started. You can check its status with:"
echo "  $systemctl_cmd status ${unit_name}.timer"
