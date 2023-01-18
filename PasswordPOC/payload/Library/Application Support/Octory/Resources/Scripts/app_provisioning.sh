#!/bin/bash

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${DIR}/stdfunc.sh"

SLACK_APP="/Applications/Slack.app"
OPASS_APP="/Applications/1Password 7.app"
GCHROME_APP="/Applications/Google Chrome.app"
SSERVICE_APP="/Applications/Self Service.app"
JC_APP="/Applications/Jumpcloud.app"
VPN_APP="/Applications/OpenVPN Connect/OpenVPN Connect.app"
VPN_BIN="/Applications/OpenVPN Connect/OpenVPN Connect.app/Contents/MacOS/OpenVPN Connect"

clean_up() {
    # Wait for the Octory process to exit
    wait_for_process "exit" "Octory"

    # Remove the Octory inputs file
    if [[ -e "/Application Support/Octory/Resources/Inputs/inputs.plist" ]]; then
        print_log "Removing Octory inputs plist file"
        /bin/rm -f "/Application Support/Octory/Resources/Inputs/inputs.plist"
    fi

    # Remove the Octory starting stage plist
    # remove_launchdaemon "/Library/LaunchDaemons/com.foursquare.app_provisioning.plist" "com.foursquare.app_provisioning.plist"
    print_log "Restarting computer"
    shutdown -r now

}

app_provisioning() {
    notify_octory config installing

    print_log "Using a jamf policy to rename computer"
    execute "/usr/local/bin/jamf" "policy" "-id" "25"

    print_log "Using a jamf policy to update Jamf inventory records for this computer and assocaiting $ACTIVE_USER as the assgined user"
    execute "/usr/local/bin/jamf" "recon" "-endUsername" "$ACTIVE_USER"

    notify_octory config installed

    notify_octory security installing

    print_log "Using a jamf policy to install the JumpCloud agent"
    if [[ ! -d "$JC_APP" ]]; then
        execute "/usr/local/bin/jamf" "policy" "-id" "9"
    fi

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
    #	Runs prelaunch parameters to suppress dialogs on OpenVPN Connect first run
    #	This command will save the settings in the user's preferences and exit
    runas_active_user "${VPN_BIN}" --accept-gdpr --skip-startup-dialogs
    #	Disable crash reporting
    runas_active_user "${VPN_BIN}" --set-setting=enable-crash-reporting --value=false
    #	Make OpenVPN list chatty
    runas_active_user "${VPN_BIN}" --set-setting=confirmation-dialogs --value=none
    #	Make OpenVPN restore connection on launch
    runas_active_user "${VPN_BIN}" --set-setting=launch-options --value=restore-connection

    notify_octory VPN installed

    #	notify_octory Brew installing
    #	print_log "Using a jamf poliy to install Homebrew (only will install for employees in the Engineering department)"
    #	execute "/usr/local/bin/jamf" "policy" "-event" "homebrew-silent"
    #	notify_octory Brew installed

    #	Let's set the dock
    print_log "Using a jamf policy to configure the dock."
    execute "/usr/local/bin/jamf" "policy" "-id" "49"
}

employee_type() {
    employee_type=$(defaults read "/Library/Application Support/Octory/Resources/inputs/inputs.plist" EmployeeType 2> /dev/null)
    case "${employee_type}" in
        New)
            print_log "Employe Typee ${employee_type} detected updating launch daemons."
            plutil -replace RunAtLoad -bool false /Library/LaunchDaemons/com.foursquare.app_provisioning.plist
            rm -f /Library/LaunchDaemons/com.foursquare.app_provisioning.plist
            plutil -replace RunAtLoad -bool true /Library/LaunchDaemons/com.foursquare.it_onboarding.plist
            ;;
        Existing)
            print_log "Employe Typee ${employee_type} detected updating launch daemons."
            plutil -replace RunAtLoad -bool false /Library/LaunchDaemons/com.foursquare.app_provisioning.plist
            rm -f /Library/LaunchDaemons/com.foursquare.app_provisioning.plist
            plutil -replace RunAtLoad -bool false /Library/LaunchDaemons/com.foursquare.it_onboarding.plist
            rm -f /Library/LaunchDaemons/com.foursquare.it_onboarding.plist
            ;;
        *)
            print_log "Employee type is ${employee_type} with length $(wc -c "${employee_type}")"
            ;;
    esac
}

main() {
    trap stop_caffeinate EXIT
    start_caffeinate
    set_datetime
    wait_for_process "launch" "Finder"
    start_octory "app_provisioning.plist"
    wait_for_octory_helper
    app_provisioning
    employee_type
    clean_up
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
