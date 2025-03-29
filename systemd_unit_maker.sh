#!/bin/zsh
#
# usage section here
#
# parse args to get:
# - a unit name
# - a command
# - --user or --system
# - --description
# - --frequency
#
# replace each space by a _ in that unit_name
#
# copy the file next to this script called ./templates/templated.service to ~/.config/systemd/user if not root or /etc/systemd/system otherwise with filename $unit_name + ".service" and do the same for the .timer template
#
# then to those new files use sed to replace [[DESCRIPTION]] by $description given by arg
#
# then to those new files use sed to replace [[FREQUENCY]] by $frequency given by arg
#
# then to those new files use sed to replace [[COMMAND]] by $command given by arg
#
# then run systemctl --user daemon-reload or the sudo non user version if root
#
# then ask the user to press enter to run systemctl start on that service file (with or without --user)
