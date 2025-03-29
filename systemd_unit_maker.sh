#!/bin/zsh

# Enable for debugging
# set -x
#
# systemd_unit_maker.sh - Creates systemd service and timer units from a command
#
# Usage:
#   ./systemd_unit_maker.sh [--user|--system] --name UNIT_NAME --command "COMMAND" 
#                           [--description "DESCRIPTION"] [--frequency "FREQUENCY" | --calendar "CALENDAR"] 
#                           [--template "TEMPLATE"] [--start] [--enable]
#
# Options:
#   --user          Install for current user (default)
#   --system        Install system-wide (requires root)
#   --name          Name for the systemd unit
#   --command       Command to run in the service
#   --description   Description of the service (optional)
#   --frequency     Timer frequency (e.g. "daily" or "1h") (optional)
#   --calendar      Timer calendar specification (e.g. "Mon..Fri *-*-* 08:00:00") (optional)
#                   Note: Use either --frequency OR --calendar. If neither is provided, no timer will be created.
#   --start         Start the service after creation (default: false)
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
frequency=""
calendar=""
template="default"
start=false
enable=false
create_timer=false

echo "=== Starting systemd unit maker ==="

# Function to print usage information
print_help() {
  cat << EOF
systemd_unit_maker.sh - Creates systemd service and timer units from a command

Usage:
  ./systemd_unit_maker.sh [--user|--system] --name UNIT_NAME --command "COMMAND" 
                         [--description "DESCRIPTION"] [--frequency "FREQUENCY" | --calendar "CALENDAR"] [--enable]

Options:
  --help, -h      Show this help message and exit
  --user          Install for current user (default)
  --system        Install system-wide (requires root)
  --name          Name for the systemd unit
  --command       Command to run in the service
  --description   Description of the service (optional)
  --frequency     Timer frequency (e.g. "daily" or "1h") (optional)
  --calendar      Timer calendar specification (e.g. "Mon..Fri *-*-* 08:00:00") (optional)
                  Note: Use either --frequency OR --calendar. If neither is provided, no timer will be created.
  --template      Template name to use (optional, default "default")
  --start         Start the service after creation (default: false)
  --enable        Enable and start the timer after creation (default: false)

Examples:
  ./systemd_unit_maker.sh --user --name backup_home --command "tar -czf /tmp/backup.tar.gz /home/user" \\
                         --description "Daily home backup" --frequency "1d"
  
  ./systemd_unit_maker.sh --user --name workday_reminder --command "notify-send 'Time to work!'" \\
                         --description "Workday reminder" --calendar "Mon..Fri *-*-* 08:00:00"
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
      create_timer=true
      shift 2
      ;;
    --calendar)
      calendar="$2"
      create_timer=true
      shift 2
      ;;
    --template)
      template="$2"
      shift 2
      ;;
    --start)
      start=true
      shift
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
if [[ -n "$frequency" ]]; then
  echo "Timer frequency: $frequency"
elif [[ -n "$calendar" ]]; then
  echo "Timer calendar: $calendar"
else
  echo "Timer: Not creating timer"
fi
echo "Template: $template"
echo "Start after creation: $(if $start; then echo "Yes"; else echo "No"; fi)"
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

# Replace spaces with underscores in unit name and convert to lowercase
unit_name=${unit_name// /_}
unit_name=${unit_name:l}  # zsh syntax for lowercase conversion

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
echo "Service file will be created at: $service_file"

# Copy service template file
echo "Copying service template file..."
if $user_mode; then
  echo "Using template: $script_dir/templates/${template}.service"
  cp "$script_dir/templates/${template}.service" "$service_file"
else
  echo "Using template with sudo: $script_dir/templates/${template}.service"
  sudo cp "$script_dir/templates/${template}.service" "$service_file"
fi
echo "Service template file copied successfully"

# Copy timer template file if needed
if $create_timer; then
  timer_file="$systemd_dir/${unit_name}.timer"
  echo "Timer file will be created at: $timer_file"
  
  echo "Copying timer template file..."
  if $user_mode; then
    echo "Using template: $script_dir/templates/${template}.timer"
    cp "$script_dir/templates/${template}.timer" "$timer_file"
  else
    echo "Using template with sudo: $script_dir/templates/${template}.timer"
    sudo cp "$script_dir/templates/${template}.timer" "$timer_file"
  fi
  echo "Timer template file copied successfully"
fi

# Replace placeholders in the service file
echo "Configuring service file..."

# Escape ampersands in command to prevent sed from interpreting them
escaped_command="$command"
if [[ "$command" == *"&"* ]]; then
  echo "Command contains ampersands, escaping them for sed..."
  escaped_command="${command//&/\\&}"
fi

if $user_mode; then
  sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$service_file"
  sed -i "s|\[\[COMMAND\]\]|$escaped_command|g" "$service_file"
else
  sudo sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$service_file"
  sudo sed -i "s|\[\[COMMAND\]\]|$escaped_command|g" "$service_file"
fi

echo "Service file configured successfully"

# Replace placeholders in the timer file if it exists
if $create_timer; then
  echo "Configuring timer file..."
  
  # Determine timer specification based on whether frequency or calendar is used
  if [[ -n "$frequency" ]]; then
    timer_spec="OnUnitActiveSec=$frequency"
  elif [[ -n "$calendar" ]]; then
    timer_spec="OnCalendar=$calendar"
  fi
  
  if $user_mode; then
    sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$timer_file"
    sed -i "s/\[\[TIMER_SPEC\]\]/$timer_spec/g" "$timer_file"
    sed -i "s/\[\[UNIT_NAME\]\]/$unit_name/g" "$timer_file"
  else
    sudo sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$timer_file"
    sudo sed -i "s/\[\[TIMER_SPEC\]\]/$timer_spec/g" "$timer_file"
    sudo sed -i "s/\[\[UNIT_NAME\]\]/$unit_name/g" "$timer_file"
  fi

  echo "Timer file configured successfully"
fi

# Reload systemd daemon
echo "Reloading systemd daemon..."
systemctl_cmd daemon-reload
echo "Systemd daemon reloaded"

echo "Systemd unit created successfully:"
echo "  Service: $service_file"
if $create_timer; then
  echo "  Timer: $timer_file"
fi
echo ""

if $start; then
  # Start the service without enabling
  echo "Starting service: ${unit_name}.service"
  systemctl_cmd start "${unit_name}.service"
  echo "Service started successfully"
fi

if $enable && $create_timer; then
  # Start and enable the timer
  echo "Enabling and starting timer: ${unit_name}.timer"
  systemctl_cmd enable --now "${unit_name}.timer"
  echo "Timer enabled and started successfully"

  echo "Timer enabled and started. You can check its status with:"
  echo "  systemctl$(if $user_mode; then echo " --user"; fi) status ${unit_name}.timer"
elif $create_timer; then
  echo "Timer created but not enabled. To enable and start the timer, run:"
  echo "  systemctl$(if $user_mode; then echo " --user"; fi) enable --now ${unit_name}.timer"
fi

unalias systemctl_cmd
