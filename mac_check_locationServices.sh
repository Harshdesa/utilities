#!/bin/bash

# crontab -e
# #* * * * * /Users/<username>/code/check_locationServices.sh

# Check Location Services status
status=$(sudo defaults read /var/db/locationd/Library/Preferences/com.apple.locationd LocationServicesEnabled 2>/dev/null)

if [[ "$status" == "1" ]]; then
osascript -e 'display notification "Location Services are ENABLED." with title "Privacy Check"'
else
osascript -e 'display notification "Location Services are DISABLED." with title "Privacy Check"'
fi
