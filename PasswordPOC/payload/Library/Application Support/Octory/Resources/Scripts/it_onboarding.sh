#!/bin/bash

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${DIR}/stdfunc.sh"

clean_up() {
    # Wait for the Octory process to exit
    wait_for_process "exit" "Octory"

    # Remove the Octory inputs file
    if [[ -e "/Application Support/Octory/Resources/Inputs/inputs.plist" ]]; then
        print_log "Removing Octory inputs plist file"
        /bin/rm -f "/Application Support/Octory/Resources/Inputs/inputs.plist"
    fi

    # Remove the Octory IT onboarding plist
    print_log "Removing Octory IT onboarding plist"
    plutil -replace RunAtLoad -bool false /Library/LaunchDaemons/com.foursquare.it_onboarding.plist
    remove_launchdaemon "/Library/LaunchDaemons/com.foursquare.it_onboarding.plist" "com.foursquare.it_onboarding.plist"

}

main() {
    trap stop_caffeinate EXIT
    remove_launchdaemon "/Library/LaunchDaemons/com.foursquare.app_provisioning.plist" "com.foursquare.app_provisioning.plist"
    start_caffeinate
    set_datetime
    wait_for_process "launch" "Finder"
    wait_for_process "launch" "OpenVPN Connect"
    pkill -9 "OpenVPN Connect"
    start_octory "it_onboarding.plist"
    wait_for_octory_helper
    clean_up
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
