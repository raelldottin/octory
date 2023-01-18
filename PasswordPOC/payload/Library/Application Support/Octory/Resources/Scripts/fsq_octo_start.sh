#!/bin/bash

# This script provides all the necessary minimum configurations for a FSQ macOS device via JAMF and also acts as a controller for Octory
exec > /var/tmp/octoControlLogStart.log 2>&1
set -x

# Variables
OCTO_APP="/Library/Application Support/Octory/Octory.app/Contents/MacOS/Octory"
OCTO_CMD="/usr/local/bin/octo-notifier"
JAMF_CTL="/usr/local/bin/jamf"
SLACK="/Applications/Slack.app"
OPASS="/Applications/1Password.app"
OPENVPN="/Applications/OpenVPN Connect/OpenVPN Connect.app/Contents/MacOS/OpenVPN Connect"
GCHROME="/Applications/Google Chrome.app"
SSERVICE="/Applications/Self Service.app"
OCTO_START_COMPLETE="/var/tmp/com.foursquare.octostart.done"

# Caffeinate the device
caffeinate -d -i -m -u &
caffeinatePID=$!

# Wait for active user session
FINDER_PROCESS=$(pgrep -l "Finder")
until [[ "$FINDER_PROCESS" != "" ]]; do
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Finder process not found. User session not active."
    sleep 1
    FINDER_PROCESS=$(pgrep -l "Finder")
done

#Collect current logged in user
ACTIVE_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

# We need to standardize the location of the octory log file
# Launch the Octory app
"$OCTO_APP" --config fsq_start.plist &

# Wait for Octory to establish a connection with the Octory helper
OCTORY_HELPER=$(grep "Valid connection with the Helper" /tmp/*-octory.log 2>/dev/null)
until [ "$OCTORY_HELPER" != "" ]; do
	echo "Waiting for a valid connection with Octory helper."
	sleep 1
	OCTORY_HELPER=$(grep "Valid connection with the Helper" /tmp/*-octory.log 2>/dev/null)
done

# Turn on all monitors to "installing" state
sleep 2;"$OCTO_CMD" monitor security -s installing;

sleep 2;"$OCTO_CMD" monitor sys -s installing;

sleep 2;"$OCTO_CMD" monitor app -s installing;

sleep 2;"$OCTO_CMD" monitor config -s installing;

sleep 2;"$OCTO_CMD" monitor Slack -s installing;

sleep 2;"$OCTO_CMD" monitor 1Password -s installing;

sleep 2;"$OCTO_CMD" monitor GChrome -s installing;

sleep 2;"$OCTO_CMD" monitor VPN -s installing;

# Apply Disk Encryption and complete Security Settings monitor
"$JAMF_CTL" policy -id 21
sleep 2;"$OCTO_CMD" monitor security -s installed

# Disable Smart Quotes and Dashes and complete System Settings monitor
"$JAMF_CTL" policy -id 23
sleep 2;"$OCTO_CMD" monitor sys -s installed

# Install Self Service, open and close the app twice to get FSQ icon to stick, then complete App Settings monitor
"$JAMF_CTL" policy -id 43
open -a "$SSERVICE" -j
SSERVICE_PROCESS=$(pgrep -l "Self Service")
until [ "$SSERVICE_PROCESS" != "" ]; do
    sleep 1
	SSERVICE_PROCESS=$(pgrep -l "Self Service")
done
sleep 2;killall "Self Service"
open -a "$SSERVICE" -j
SSERVICE_PROCESS=$(pgrep -l "Self Service")
until [ "$SSERVICE_PROCESS" != "" ]; do
    sleep 1
	SSERVICE_PROCESS=$(pgrep -l "Self Service")
done
sleep 2;killall "Self Service"

sleep 2;"$OCTO_CMD" monitor app -s installed

# Rename Computer and complete Configuration Settings monitor
"$JAMF_CTL" policy -id 25; sleep 2; "$OCTO_CMD" monitor config -s installed

# Now check for Slack, 1Password7, and Google Chrome installed by VPP - if not installed, call "installomator silent" to add them, then complete the app monitors for both items.
# Is Slack installed?
if [ -d "$SLACK" ]; then
    sleep 2;"$OCTO_CMD" monitor Slack -s installed
else
    "$JAMF_CTL" policy -id 85; sleep 2; "$OCTO_CMD" monitor Slack -s installed
fi


# Is 1Password installed?
if [ -d "$OPASS" ]; then
    sleep 2; "$OCTO_CMD" monitor 1Passsword -s installed
else
    "$JAMF_CTL" policy -id 86; sleep 2; "$OCTO_CMD" monitor 1Password -s installed
fi

# Is Google Chrome installed?
if [ -d "$GCHROME" ]; then
    sleep 2; "$OCTO_CMD" monitor GChrome -s installed
else
    "$JAMF_CTL" policy -id 45; sleep 2; "$OCTO_CMD" monitor GChrome -s installed
fi

# Is OpenVPN Connect installed?
if [[ ! -f "$OPENVPN" ]]; then
	"$JAMF_CTL" policy -id 96
fi

# Runs prelaunch parameters to suppress dialogs on OpenVPN Connect first run
# This command will save the settings in the user's preferences and exit
/bin/launchctl asuser "$(id -u "$ACTIVE_USER")" sudo -iu "$ACTIVE_USER" "$OPENVPN" --accept-gdpr --skip-startup-dialogs

# Disable crash reporting
/bin/launchctl asuser "$(id -u "$ACTIVE_USER")" sudo -iu "$ACTIVE_USER" "$OPENVPN" --set-setting=enable-crash-reporting --value=false

# Make OpenVPN list chatty
/bin/launchctl asuser "$(id -u "$ACTIVE_USER")" sudo -iu "$ACTIVE_USER" "$OPENVPN" --set-setting=confirmation-dialogs --value=none

# Make OpenVPN restore connection on launch
/bin/launchctl asuser "$(id -u "$ACTIVE_USER")" sudo -iu "$ACTIVE_USER" "$OPENVPN" --set-setting=launch-options --value=restore-connection

sleep 2; "$OCTO_CMD" monitor VPN -s installed

# Let's set the dock
"$JAMF_CTL" policy -id 49

while [ ! -f "$OCTO_START_COMPLETE" ]; do
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for user click Finish."
    sleep 10
done

kill $caffeinatePID
