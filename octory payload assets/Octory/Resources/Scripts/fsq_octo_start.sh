#!/bin/sh

# This script provides all the necessary minimum configurations for a FSQ macOS device via JAMF and also acts as a controller for Octory
exec > /var/tmp/octoControlLogStart.log 2>&1
set -x

# Variables
OCTO_APP="/Library/Application Support/Octory/Octory.app/Contents/MacOS/Octory"
OCTO_CMD="/usr/local/bin/octo-notifier"
JAMF_CTL="/usr/local/bin/jamf"
SLACK="/Applications/Slack.app"
OPASS="/Applications/1Password.app"
GCHROME="/Applications/Google Chrome.app"
SSERVICE="/Applications/Self Service.app"
OCTO_START_COMPLETE="/var/tmp/com.foursquare.octostart.done"

caffeinate -d -i -m -u &
caffeinatePID=$!

# Wait for active user session
FINDER_PROCESS=$(pgrep -l "Finder")
until [ "$FINDER_PROCESS" != "" ]; do
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Finder process not found. User session not active."
    sleep 1
    FINDER_PROCESS=$(pgrep -l "Finder")
done

"$OCTO_APP" --config fsq_start.plist &

sleep 3;

# Turn on all monitors to "installing" state
"$OCTO_CMD" monitor security -s installing;
sleep 2

"$OCTO_CMD" monitor sys -s installing;
sleep 2

"$OCTO_CMD" monitor app -s installing;
sleep 2

"$OCTO_CMD" monitor config -s installing;
sleep 2

"$OCTO_CMD" monitor Slack -s installing;
sleep 2

"$OCTO_CMD" monitor 1Password -s installing;
sleep 2

"$OCTO_CMD" monitor GChrome -s installing;
sleep 2

"$OCTO_CMD" monitor OpenVPN -s installing;
sleep 2

# Apply Disk Encryption and complete Security Settings monitor
"$JAMF_CTL" policy -id 21; "$OCTO_CMD" monitor security -s installed; sleep 3
    
# Disable Smart Quotes and Dashes and complete System Settings monitor
"$JAMF_CTL" policy -id 23; "$OCTO_CMD" monitor sys -s installed; sleep 3

# Install Self Service, open and close the app twice to get FSQ icon to stick, then complete App Settings monitor
"$JAMF_CTL" policy -id 43; open -a "$SSERVICE" -j; sleep 5; killall "Self Service"; open -a "$SSERVICE" -j; sleep 5; killall "Self Service"; "$OCTO_CMD" monitor app -s installed;
sleep 3

# Rename Computer and complete Configuration Settings monitor
"$JAMF_CTL" policy -id 25; "$OCTO_CMD" monitor config -s installed; sleep 3

# Now check for Slack, 1Password7, and Google Chrome installed by VPP - if not installed, call "installomator silent" to add them, then complete the app monitors for both items.
# Is Slack installed?
if [ -d "$SLACK" ]; then
    "$OCTO_CMD" monitor Slack -s installed
    else
    "$JAMF_CTL" policy -id 85; "$OCTO_CMD" monitor Slack -s installed
fi

sleep 3

# Is 1Password installed?
if [ -d "$OPASS" ]; then
    "$OCTO_CMD" monitor 1Passsword -s installed
    else
    "$JAMF_CTL" policy -id 86; "$OCTO_CMD" monitor 1Password -s installed
fi

sleep 3

#final stage of automated setup, remove the LaunchDaemon
rm -rf /Library/LaunchDaemons/com.foursquare.octory_start.plist

# Is Google Chrome installed?
if [ -d "$GCHROME" ]; then
    "$OCTO_CMD" monitor GChrome -s installed
    else
    "$JAMF_CTL" policy -id 45; "$OCTO_CMD" monitor GChrome -s installed
fi

# Install Open VPN v3 Client and then set the dock, final steps
"$JAMF_CTL" policy -id 96; "$JAMF_CTL" policy -id 49; "$OCTO_CMD" monitor OpenVPN -s installed
sleep 2

while [ ! -f "$OCTO_START_COMPLETE" ]; do
    echo "$(date "+%Y-%m-%d %H:%M:%S"): Waiting for user click Finish."
    sleep 10
done
