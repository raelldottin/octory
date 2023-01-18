#!/bin/bash

CAFFEINATEPID=""
ACTIVE_USER=""
NTP_SERVER=${NTP_SERVER:-time.apple.com}
OCTO_BIN="/Library/Application Support/Octory/Octory.app/Contents/MacOS/Octory"
OCTO_CMD="/usr/local/bin/octo-notifier"

set_datetime() {
    #	Syncing date and time with time.apple.com or user specified time server
    echo sntp -sS "${NTP_SERVER}"
    sntp -sS "${NTP_SERVER}"
}

get_active_user() {
    #	Collect current logged in user
    ACTIVE_USER=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }')
}

print_log() {
    #	Print a log message to standard output and system log
    message="${*}"
    timestamp=$(date -u +%F\ %T)

    get_active_user
    if [[ "${message}" == "${previous_message}" ]]; then
        ((logrepeat = logrepeat + 1))
        return
    fi
    if [[ (${logrepeat} -gt 0) && ("${message}" != "${previous_message}") ]]; then
        echo "${timestamp}:${ACTIVE_USER}[$$] : Last message repeated {$logrepeat} times"
        logger -i "Last message repeated {$logrepeat} times"
        logrepeat=0
    fi
    if [[ $logrepeat -eq 0 ]]; then
        echo "${timestamp}:${ACTIVE_USER}[$$] : ${message}"
        logger -i "${message}"
        previous_message="${message}"
    fi
}

start_caffeinate() {
    caffeinate -d -i -m -u &
    CAFFEINATEPID=${!}
    print_log "Started the caffeinate process: pid ${CAFFEINATEPID}"
}

stop_caffeinate() {
    if [[ -n "${CAFFEINATEPID}" ]]; then
        print_log "Stopped the caffeinate process: pid ${CAFFEINATEPID}"
        kill "${CAFFEINATEPID}"
    fi
}

wait_for_process() {
    # Waits for the process to either launch or exit
    # Usage: wait_for_process [status] [name]
    status="${1}"
    name="${2}"
    case "$status" in
        launch)
            print_log "${name} process search output: $(pgrep -l "${name}")"
            while [[ -z "$(pgrep -l "${name}")" ]]; do
                print_log "Waiting for ${name} to ${status}"
                sleep 1
            done
            ;;
        exit)
            print_log "${name} process search output: $(pgrep -l "${name}")"
            until [[ -z "$(pgrep -l "${name}")" ]]; do
                print_log "Waiting for ${name} to ${status}"
                sleep 1
            done
            ;;
    esac
}

runas_active_user() {
    get_active_user
    launchctl "asuser" "$(id -u "${ACTIVE_USER}")" sudo -iu "${ACTIVE_USER}" "$@"
    print_log "Running \"${*}\" as ${ACTIVE_USER}"
}

start_octory() {
    print_log "Launching the Octory app with plist ${1}"
    if [[ -r "/Library/Application Support/Octory/${1}" ]]; then
        runas_active_user "${OCTO_BIN}" --config "${1}" &
    else
        print_log "Unable to find the plist file: ${1}"
        exit 1
    fi
}

wait_for_octory_helper() {
    print_log "This will fail if the octory log file isn't located in /tmp/"${ACTIVE_USER}"-octory.log"
    until [[ -n "${octory_helper}" ]]; do
        print_log "Waiting for a valid connection with Octory helper."
        octory_helper=$(tail -4 /tmp/"${ACTIVE_USER}"-octory.log 2> /dev/null | grep "Valid connection with the Helper" 2> /dev/null)
    done
    sleep 3
}

notify_octory() {
    monitor_name="$1"
    monitor_state="$2"
    print_log "Updating octory monitor $monitor_name to the following state $monitor_state"
    #	Octory and octory-notifier needs to run as the same user
    runas_active_user "$OCTO_CMD" monitor "$monitor_name" -s "$monitor_state"
    #	"$OCTO_CMD" monitor "$monitor_name" -s "$monitor_state"
}

trigger_octory() {
    trigger_name="$1"
    print_log "Triggering octory monitor ${monitor_name}"
    #	Octory and octory-notifier needs to run as the same user
    runas_active_user "${OCTO_CMD}" trigger "${trigger_name}"
    #	"${OCTO_CMD}" trigger "${trigger_name}"
}

execute() {
    for ((i = 0; i < 5; i++)); do
        if "${@}"; then
            print_log "Process ${*} : returned ${?}"
            break
        else
            print_log "Process ${*} : returned $?"
        fi
    done
}

remove_launchdaemon() {
    filename="${1}"
    label="${2}"

    if [[ -z "${filename}" || -z "${label}" ]]; then
        echo "Usage: remove_launchdaemon [file] [label]"
        return
    fi
    if [[ -e "${filename}" ]]; then
        /bin/launchctl unload -F "${filename}"
        /bin/rm -f "${filename}"
    fi
    if /bin/launchctl list | /usr/bin/grep -q "${label}"; then
        /bin/launchctl stop "${label}"
        /bin/launchctl remove "${label}"
    fi
}
