#!/bin/bash

PARENT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${PARENT_DIR}/stdfunc.sh"

clean_up() {
    if [[ -f /Library/LaunchDaemons/com.foursquare.updateos.plist ]]; then
        print_log "Removing the Octory launch daemon: /Library/LaunchDaemons/com.foursquare.updateos.plist"
        /bin/rm -f /Library/LaunchDaemons/com.foursquare.updateos.plist
    fi
    if [[ "$(launchctl list | grep com.foursquare.updateos | awk '{print $3}')" == "com.foursquare.updateos" ]]; then
        print_log "Unloading launch daemon: com.foursquare.updateos"
        launchctl unload com.foursquare.updateos
    fi
}

version_comparison() {
    [[ "${1}" == "$(echo -e "${1}\n${2}" | "/Library/Application Support/Octory/Resources/bin/gsort" -V | head -n1)" ]]
}

check_for_update() {
    macos_version="$(/usr/bin/sw_vers -productVersion)"
    required_macos_version="$("/Library/Application Support/Octory/Resources/bin/scout" read -i "${PARENT_DIR}/../../UpdateOS.plist" -f plist General.Variables.RequiredOS)"
    print_log "macOS Version: ${macos_version}"
    print_log "Required macOS Version: ${required_macos_version}"
    if version_comparison "${macos_version}" "${required_macos_version}" && [[ "${macos_version}" != "${required_macos_version}" ]]; then
        print_log "macOS require updates."
        wait_for_process "launch" "Finder"
        start_octory "UpdateOS.plist"
        wait_for_process "exit" "Octory"
    else
        print_log "macOS is update to date."
        clean_up
    fi
}

main() {
    trap stop_caffeinate EXIT
    start_caffeinate
    check_for_update
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
