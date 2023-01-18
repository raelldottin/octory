#!/bin/sh

# Install the helper

cd "/Library/Application Support/Octory/HelperInstall"
./installHelper.sh

# Set and load the Octory start script in Launch Daemons
chmod 644 /Library/LaunchDaemons/com.foursquare.octory_start.plist
chown root:wheel /Library/LaunchDaemons/com.foursquare.octory_start.plist

# load the LaunchDaemon
launchctl load -w /Library/LaunchDaemons/com.foursquare.octory_start.plist