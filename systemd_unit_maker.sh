#!/bin/zsh

# Script version
VERSION="1.0.0"

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
  --version, -v   Show version information and exit
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
    -v|--version)
      echo "systemd_unit_maker.sh version $VERSION"
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

# Check if template contains "boot" and if so, set create_timer=true
if [[ "$template" == *"boot"* ]] && [[ "$create_timer" == "false" ]]; then
  create_timer=true
  # Set a default frequency if none was provided
  if [[ -z "$frequency" ]] && [[ -z "$calendar" ]]; then
    frequency="1d"  # Default to daily if no schedule specified
  fi
  echo "Boot template detected: Timer will be created automatically"
fi

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
elif [[ "$create_timer" == "true" ]]; then
  echo "Timer: Creating timer for boot template"
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

# Create temporary directory for editing files
temp_dir=$(mktemp -d)
echo "Created temporary directory: $temp_dir"

# Define temp and final file paths
temp_service_file="$temp_dir/${unit_name}.service"
service_file="$systemd_dir/${unit_name}.service"
echo "Service file will be created at: $service_file"

# Copy service template file to temp directory
echo "Copying service template file to temp directory..."
cp "$script_dir/templates/${template}.service" "$temp_service_file"
echo "Service template file copied to temp directory"

# Define temp timer file if needed
if $create_timer; then
  temp_timer_file="$temp_dir/${unit_name}.timer"
  timer_file="$systemd_dir/${unit_name}.timer"
  echo "Timer file will be created at: $timer_file"
  
  echo "Copying timer template file to temp directory..."
  cp "$script_dir/templates/${template}.timer" "$temp_timer_file"
  echo "Timer template file copied to temp directory"
fi

# Replace placeholders in the service file
echo "Configuring temporary service file..."

# Escape ampersands in command to prevent sed from interpreting them
escaped_command="$command"
if [[ "$command" == *"&"* ]]; then
  echo "Command contains ampersands, escaping them for sed..."
  escaped_command="${command//&/\\&}"
fi

sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$temp_service_file"
sed -i "s|\[\[COMMAND\]\]|$escaped_command|g" "$temp_service_file"

echo "Temporary service file configured with placeholders"

# Replace placeholders in the timer file if it exists
if $create_timer; then
  echo "Configuring temporary timer file..."
  
  # Determine timer specifications based on whether frequency or calendar is used
  if [[ -n "$frequency" ]]; then
    timer_spec="OnUnitActiveSec=$frequency"
    frequency_spec="$frequency"
  elif [[ -n "$calendar" ]]; then
    timer_spec="OnCalendar=$calendar"
    calendar_spec="$calendar"
  elif [[ "$template" == *"boot"* ]]; then
    # For boot templates with no specified timing, use the boot template's default
    # This will rely on the template having the correct timing specifications
    timer_spec=""
    frequency_spec=""
    calendar_spec=""
  fi
  
  # Replace standard placeholders
  sed -i "s/\[\[DESCRIPTION\]\]/$description/g" "$temp_timer_file"
  sed -i "s/\[\[UNIT_NAME\]\]/$unit_name/g" "$temp_timer_file"
  
  # Check which placeholder style the timer template uses
  if grep -q "\[\[TIMER_SPEC\]\]" "$temp_timer_file"; then
    echo "Using [[TIMER_SPEC]] placeholder in timer file"
    sed -i "s/\[\[TIMER_SPEC\]\]/$timer_spec/g" "$temp_timer_file"
  else
    # Check for alternative placeholders
    if [[ -n "$frequency" ]] && grep -q "\[\[FREQUENCY\]\]" "$temp_timer_file"; then
      echo "Using [[FREQUENCY]] placeholder in timer file"
      sed -i "s/\[\[FREQUENCY\]\]/$frequency_spec/g" "$temp_timer_file"
    fi
    
    if [[ -n "$calendar" ]] && grep -q "\[\[CALENDAR\]\]" "$temp_timer_file"; then
      echo "Using [[CALENDAR]] placeholder in timer file"
      sed -i "s/\[\[CALENDAR\]\]/$calendar_spec/g" "$temp_timer_file"
    fi
  fi

  echo "Temporary timer file configured with placeholders"
fi

# Determine which editor to use
editor_cmd="nano"
if command -v nvim &> /dev/null; then
  editor_cmd="nvim"
fi

# Open files in editor for manual editing
edit_files=("$temp_service_file")
if $create_timer; then
  edit_files+=("$temp_timer_file")
fi

echo "Opening files for editing with $editor_cmd..."
echo "Please review and edit the files, then save and exit the editor to continue."
$editor_cmd -p "${edit_files[@]}"

# Check if any of the files are empty after editing
for file in "${edit_files[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Error: File $file is empty after editing. Aborting."
    rm -rf "$temp_dir"
    exit 1
  fi
done

echo "Files edited successfully"

# Function to check if file exists and show diff
check_and_confirm_overwrite() {
  local src="$1"
  local dest="$2"
  local need_sudo="$3"
  local file_type="$4"

  if [[ -f "$dest" ]]; then
    echo "Warning: $file_type file already exists at $dest"
    echo "Showing diff between existing and new file:"
    echo "----------------------------------------"
    
    # Create a temporary copy of the existing file for comparison
    local existing_temp=$(mktemp)
    if [[ "$need_sudo" == "true" ]]; then
      sudo cat "$dest" > "$existing_temp"
    else
      cat "$dest" > "$existing_temp"
    fi
    
    # Show the diff
    diff -u "$existing_temp" "$src" || true
    echo "----------------------------------------"
    
    # Ask for confirmation
    read -q "REPLY?Do you want to overwrite the existing file? (y/n) "
    echo ""
    
    # Clean up temp file
    rm -f "$existing_temp"
    
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      echo "Proceeding with overwrite..."
      return 0
    else
      echo "Skipping overwrite of $dest"
      return 1
    fi
  else
    # File doesn't exist, no confirmation needed
    return 0
  fi
}

# Copy edited files to their final destinations
echo "Copying edited files to final destinations..."

if $user_mode; then
  if check_and_confirm_overwrite "$temp_service_file" "$service_file" "false" "Service"; then
    cp "$temp_service_file" "$service_file"
  fi
  
  if $create_timer; then
    if check_and_confirm_overwrite "$temp_timer_file" "$timer_file" "false" "Timer"; then
      cp "$temp_timer_file" "$timer_file"
    fi
  fi
else
  if check_and_confirm_overwrite "$temp_service_file" "$service_file" "true" "Service"; then
    sudo cp "$temp_service_file" "$service_file"
  fi
  
  if $create_timer; then
    if check_and_confirm_overwrite "$temp_timer_file" "$timer_file" "true" "Timer"; then
      sudo cp "$temp_timer_file" "$timer_file"
    fi
  fi
fi

echo "Files installation completed"

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

# Clean up temporary directory
echo "Cleaning up temporary files..."
rm -rf "$temp_dir"
echo "Temporary files removed"

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
