#!/bin/bash

# Run as sysop: source the environment *inside* the command and then run update-config
su - sysop -c "source /home/sysop/.bash_profile && seiscomp update-config seedlink"

# Now start supervisord as root, which manages processes running as sysop
exec supervisord -c /etc/supervisord.conf

