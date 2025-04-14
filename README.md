# Systemd Unit Maker

A convenient ZSH script that simplifies the creation of systemd service and timer units from command line instructions.

## Overview

The Systemd Unit Maker script allows you to easily create systemd service and timer units with minimal manual editing. It handles all the boilerplate configuration, provides a straightforward command-line interface for defining your services, and allows you to fine-tune the units before installation.

## Requirements

- Systemd
- ZSH shell
- Text editor (nano by default, nvim if available)
- Appropriate permissions (root for system-wide units)

## Installation

1. Clone this repository or download the script and template files
2. Ensure the script has executable permissions:
   ```bash
   chmod +x systemd_unit_maker.sh
   ```
3. Make sure the templates directory is in the same directory as the script

## Usage

### Basic Syntax

```bash
./systemd_unit_maker.sh [--user|--system] --name UNIT_NAME --command "COMMAND" \
                        [--description "DESCRIPTION"] [--template "TEMPLATE"] \
                        [--start] [--enable] [--no-timer]
```

### Options

- `--user`: Install for current user (default behavior)
- `--system`: Install system-wide (requires root)
- `--name`: Name for the systemd unit (required)
- `--command`: Command to run in the service (required)
- `--description`: Description of the service (optional)
- `--template`: Template name to use (optional, default "default")
- `--start`: Start the service after creation without enabling it (default: false)
- `--enable`: Enable and start the timer after creation (default: false)
- `--no-timer`: Do not create a timer unit, only create the service unit (default: false)

### Templates

The script includes several templates:

- `default`: Standard systemd service/timer
- `zsh`: Service that runs commands using ZSH
- `zsh_boot`: Service that runs at boot time using ZSH

For boot templates (`*_boot`), a timer is automatically created even without specifying a frequency or calendar.

### Interactive Editing

After initial configuration, the script will open your editor (nano by default, nvim if available) to allow you to make final adjustments to the unit files before installation.

### Examples

#### Create a backup service for the current user

```bash
./systemd_unit_maker.sh --user --name backup_home \
                        --command "tar -czf /tmp/backup.tar.gz /home/user" \
                        --description "Daily home backup" \
                        --enable
```

#### Create a system-wide log rotation service

```bash
sudo ./systemd_unit_maker.sh --system --name log_rotation \
                            --command "/usr/local/bin/rotate_logs.sh" \
                            --description "Hourly log rotation" \
                            --enable
```

#### Create a cleanup service without enabling it

```bash
./systemd_unit_maker.sh --user --name weekly_cleanup \
                        --command "/home/user/scripts/cleanup.sh" \
                        --description "Weekly temporary file cleanup"
```

#### Create a service that runs without a timer

```bash
./systemd_unit_maker.sh --user --name on_demand_service \
                        --command "notify-send 'Running on demand'" \
                        --description "On-demand service" \
                        --no-timer
```

#### Create a service with a custom template and start it immediately

```bash
./systemd_unit_maker.sh --user --name custom_service \
                        --command "/home/user/scripts/custom_script.sh" \
                        --description "Custom service using ZSH template" \
                        --template "zsh" \
                        --start
```

#### Create a boot-time service that runs on startup

```bash
./systemd_unit_maker.sh --user --name startup_script \
                        --command "/home/user/scripts/startup.sh" \
                        --description "Run script at system boot" \
                        --template "zsh_boot" \
                        --enable
```

## Timer Configuration

When a timer is created (which is the default unless `--no-timer` is specified), the script will:

1. Create a default timer unit file with common configurations commented out
2. Open the timer file in your editor so you can customize the timing
3. By default, a daily timer configuration is used for regular templates

### Timer Configuration Examples

You can customize the timer unit file during the interactive editing phase by uncommenting or modifying the timer settings:

- `OnBootSec=5min`: Run 5 minutes after boot (automatically used for boot templates)
- `OnCalendar=*-*-* *:00:00`: Run every hour
- `OnCalendar=*-*-* 02:00:00`: Run every day at 2 AM
- `OnCalendar=Mon..Fri *-*-* 08:00:00`: Run on weekdays at 8 AM
- `OnUnitActiveSec=1d`: Run daily after the last execution
- `OnUnitActiveSec=1h`: Run hourly after the last execution
- `AccuracySec=1min`: Set timer accuracy to 1 minute

For more complex timer expressions, refer to the [systemd.timer documentation](https://www.freedesktop.org/software/systemd/man/systemd.timer.html).

## Features

### Automatic Editor Opening

The script will open your preferred text editor (nano by default, nvim if available) to let you make final adjustments to the service and timer files before they are installed.

### File Overwrite Protection

If the service or timer file already exists, the script will:
1. Show a diff between the existing and new file
2. Ask for confirmation before overwriting
3. Allow you to skip overwriting specific files

### Automatic Boot Templates

When using templates with "boot" in their name (e.g., `zsh_boot`), a timer will be created automatically with boot-specific settings. These timers are configured to run shortly after system boot and then once daily thereafter.

## Troubleshooting

If you encounter issues:

1. Check the status of your service and timer:
   ```bash
   systemctl --user status unit_name.service
   systemctl --user status unit_name.timer
   ```

2. View the logs for your service:
   ```bash
   journalctl --user -u unit_name.service
   ```

3. Ensure your command works when run manually

4. Verify the systemd units were created in the correct location:
   - User units: `~/.config/systemd/user/`
   - System units: `/etc/systemd/system/`

5. Check for syntax errors in your service or timer file:
   ```bash
   systemd-analyze verify unit_name.service
   systemd-analyze verify unit_name.timer
   ```
