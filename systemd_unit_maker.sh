#!/bin/zsh

# parse args to get:
# - a unit name
# - --user or --system
# --description
# --freq (optional)
#
# replace each space by a _ in that unit_name
#
# copy the file next to this script called templated.service to ~/.config/systemd/user if not root or /etc/systemd/system otherwise with filename $unit_name + ".service" and do the same for the .timer template
#
# then to those new files use sed to replace [[DESCRIPTION]] by $description given by arg
#
# then to those new files use sed to replace [[frequency]] by $description given by arg
