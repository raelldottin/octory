#!/bin/bash

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${DIR}/stdfunc.sh"

SLACK_APP="/Applications/Slack.app"
OPASS_APP="/Applications/1Password 7.app"
GCHROME_APP="/Applications/Google Chrome.app"
SSERVICE_APP="/Applications/Self Service.app"
VPN_APP="/Applications/OpenVPN Connect/OpenVPN Connect.app"

clean_up() {
    # Remove the Octory inputs file
    if [[ -e "/Application Support/Octory/Resources/Inputs/inputs.plist" ]]; then
        print_log "Removing Octory inputs plist file"
        /bin/rm -f "/Application Support/Octory/Resources/Inputs/inputs.plist"
    fi
    print_log "Removing the Octory launch daemon: /Library/LaunchDaemons/com.foursquare.app_provisioning.plist"
    plutil -replace RunAtLoad -bool false /Library/LaunchDaemons/com.foursquare.app_provisioning.plist
    rm -f /Library/LaunchDaemons/com.foursquare.app_provisioning.plist

    print_log "Restarting computer"
    shutdown -r now
}

app_provisioning() {
    notify_octory config installing

    print_log "Using a jamf policy to rename computer"
    execute "/usr/local/bin/jamf" "policy" "-id" "25"

    notify_octory config installed

    notify_octory security installing

    print_log "Using a jamf policy to install CrowdStrike"
    execute "/usr/local/bin/jamf" "policy" "-id" "65"
    execute "/usr/local/bin/jamf" "policy" "-id" "98"

    print_log "Using a jamf policy to apply Disk Encryption"
    execute "/usr/local/bin/jamf" "policy" "-id" "112"

    notify_octory security installed

    notify_octory sys installing

    print_log "Using a jamf policy to disable Smart Quotes and Dashes and complete System Settings monitor"
    execute "/usr/local/bin/jamf" "policy" "-id" "23"

    notify_octory sys installed

    notify_octory app installing

    if [[ ! -d "$SSERVICE_APP" ]]; then
        print_log "Using a jamf policy to install Self Service"
        execute "/usr/local/bin/jamf" "policy" "-id" "43"
    fi

    notify_octory app installed

    #	Now check for Slack, 1Password7, and Google Chrome installed by VPP - if not installed, call "installomator silent" to add them.

    notify_octory Slack installing

    if [[ ! -d "${SLACK_APP}" ]]; then
        print_log "Using a jamf policy to install Slack"
        execute "/usr/local/bin/jamf" "policy" "-id" "85"
    fi

    notify_octory Slack installed

    notify_octory 1Password installing

    if [[ ! -d "${OPASS_APP}" ]]; then
        print_log "Using a jamf policy to install 1Password"
        execute "/usr/local/bin/jamf" "policy" "-id" "86"
    fi

    notify_octory 1Password installed

    notify_octory GChrome installing

    if [[ ! -d "${GCHROME_APP}" ]]; then
        print_log "Using a jamf policy to install Google Chrome."
        execute "/usr/local/bin/jamf" "policy" "-id" "45"
    fi

    notify_octory GChrome installed

    notify_octory VPN installing

    if [[ ! -d "${VPN_APP}" ]]; then
        print_log "Using a jamf policy to install OpenVPN."
        execute "/usr/local/bin/jamf" "policy" "-id" "96"
    fi

    notify_octory VPN installed

    notify_octory Finish installing

    #	Let's set the dock
    print_log "Using a jamf policy to configure the dock."
    execute "/usr/local/bin/jamf" "policy" "-id" "49"

    #	Update the device inventory records in Jamf
    #execute "/usr/local/bin/jamf" "recon"

    # Remove if ldap authentication is enabled for the Jamf prestage
    print_log "Using a jamf policy to update Jamf inventory records for this computer and associating $ACTIVE_USER as the assigned user"
    execute "/usr/local/bin/jamf" "recon" "-endUsername" "$ACTIVE_USER"

    notify_octory Finish installed

    killall Octory

}

main() {
    trap stop_caffeinate EXIT
    start_caffeinate
    wait_for_process "launch" "Finder"
    start_octory "app_provisioning.plist"
    wait_for_octory_helper
    app_provisioning
    clean_up
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
