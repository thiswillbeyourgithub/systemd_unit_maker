# Systemd Unit Maker

A convenient shell script that simplifies the creation of systemd service and timer units from command line instructions.

## Overview

The Systemd Unit Maker script allows you to easily create systemd service and timer units without manually editing unit files. It handles all the boilerplate configuration and provides a straightforward command-line interface for defining your services.

## Requirements

- Systemd
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
                        [--description "DESCRIPTION"] [--frequency "FREQUENCY"] [--enable]
```

### Options

- `--user`: Install for current user (default behavior)
- `--system`: Install system-wide (requires root)
- `--name`: Name for the systemd unit (required)
- `--command`: Command to run in the service (required)
- `--description`: Description of the service (optional)
- `--frequency`: Timer frequency (e.g. "daily" or "1h") (optional, default "1d")
- `--enable`: Enable and start the timer after creation (default: false)

### Examples

#### Create a daily backup service for the current user

```bash
./systemd_unit_maker.sh --user --name backup_home \
                        --command "tar -czf /tmp/backup.tar.gz /home/user" \
                        --description "Daily home backup" \
                        --frequency "1d" \
                        --enable
```

#### Create a system-wide log rotation service that runs hourly

```bash
sudo ./systemd_unit_maker.sh --system --name log_rotation \
                            --command "/usr/local/bin/rotate_logs.sh" \
                            --description "Hourly log rotation" \
                            --frequency "1h" \
                            --enable
```

#### Create a weekly cleanup service without enabling it

```bash
./systemd_unit_maker.sh --user --name weekly_cleanup \
                        --command "/home/user/scripts/cleanup.sh" \
                        --description "Weekly temporary file cleanup" \
                        --frequency "weekly"
```

## Common Timer Frequencies

- `hourly` or `1h`: Run once per hour
- `daily` or `1d`: Run once per day
- `weekly`: Run once per week
- `monthly`: Run once per month
- `*:0/15`: Run every 15 minutes
- `Mon,Thu`: Run on Monday and Thursday
- `yearly` or `annually`: Run once per year

For more complex timer expressions, refer to the [systemd.timer documentation](https://www.freedesktop.org/software/systemd/man/systemd.timer.html).

## Managing Created Units

After creating your units, you can manage them with standard systemd commands:

### For user units:

```bash
# Check timer status
systemctl --user status unit_name.timer

# Stop timer
systemctl --user stop unit_name.timer

# Disable timer (prevent from starting at boot)
systemctl --user disable unit_name.timer

# Run the service immediately (without waiting for timer)
systemctl --user start unit_name.service
```

### For system units:

```bash
# Check timer status
sudo systemctl status unit_name.timer

# Stop timer
sudo systemctl stop unit_name.timer

# Disable timer (prevent from starting at boot)
sudo systemctl disable unit_name.timer

# Run the service immediately (without waiting for timer)
sudo systemctl start unit_name.service
```

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
