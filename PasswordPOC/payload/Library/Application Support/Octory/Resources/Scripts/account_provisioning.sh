#!/bin/bash

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${DIR}/stdfunc.sh"

# prefix for the user agent string used by curl
CLIENT="octory-zero-touch"
# suffix for the user agent string used by curl
VERSION="1.0.0"
# user agent used by curl
USER_AGENT="$CLIENT/$VERSION"
# process id of the cafeinated process
CAFFEINATEPID=""
# current logged in user
ACTIVE_USER=""
# jumpcloud system id of current device
SYSTEMID=""
# api key used to communicate with jumpcloud restful api
APIKEY=""
# jumpcloud user id of the user to bind from jumpcloud to the current device
USERID=""
# path to the file that is created to indicate that the user has successfully validated their identity
DEP_N_DONE="/var/tmp/com.octory.done"
# path to the file that is created to indicate that the user has successfully validated their identity
DEP_N_REGISTER_DONE="/var/tmp/com.octory.registration.done"
# path to the octory pre-configuration plist
DAEMON="com.foursquare.account_provisioning.plist"
# log message counter
logrepeat=0
# log previous message
previous_message=""

# THE SETTINGS BELOW ARE STORED IN /var/tmp/ade_settings.plist
# /var/tmp/ade_settings.plist admin)

# Bind user as admin or standard user
# Admin user: admin="true"
# Standard user: admin="false"
admin=""

# JumpCloud System Group ID For DEP Enrollment
DEP_ENROLLMENT_GROUP_ID=""

# JumpCloud System Group ID For DEP POST Enrollment
DEP_POST_ENROLLMENT_GROUP_ID=""

# Boolean to delete the enrollment user set through MDM
# Set to false to keep the enrollment users profile on the system
# Ex: DELETE_ENROLLMENT_USERS=false
DELETE_ENROLLMENT_USERS=""

# Username of the enrollment user account configured in the MDM.
# This account will be deleted if the above boolean is set to true.
ENROLLMENT_USER=""

# NTP server, set to time.apple.com by default, Ensure time is correct
NTP_SERVER=""

# JumpCloud Connect Key
YOUR_CONNECT_KEY=""

# Encrypted API Key
ENCRYPTED_KEY=""

runtime_vars() {
    print_log "Loading runtime variables."
    admin="$(defaults read /var/tmp/ade_settings.plist admin)"
    DEP_ENROLLMENT_GROUP_ID="$(defaults read /var/tmp/ade_settings.plist DEP_ENROLLMENT_GROUP_ID)"
    DEP_POST_ENROLLMENT_GROUP_ID="$(defaults read /var/tmp/ade_settings.plist DEP_POST_ENROLLMENT_GROUP_ID)"
    DELETE_ENROLLMENT_USERS="$(defaults read /var/tmp/ade_settings.plist DELETE_ENROLLMENT_USERS)"
    ENROLLMENT_USER="$(defaults read /var/tmp/ade_settings.plist ENROLLMENT_USER)"
    NTP_SERVER="$(defaults read /var/tmp/ade_settings.plist NTP_SERVER)"
    YOUR_CONNECT_KEY="$(defaults read /var/tmp/ade_settings.plist YOUR_CONNECT_KEY)"
    ENCRYPTED_KEY="$(defaults read /var/tmp/ade_settings.plist ENCRYPTED_KEY)"
    DECRYPT_USER_ID="$(defaults read /var/tmp/ade_settings.plist DECRYPT_USER_ID)"
}

# Used to create $ENCRYPTED_KEY
EncryptKey() {
    #	Usage: EncryptKey "API_KEY" "DECRYPT_USER_UID" "ORG_ID"
    local ENCRYPTION_KEY=${2}${3}
    local ENCRYPTED_KEY=$(echo "${1}" | /usr/bin/openssl enc -e -base64 -A -aes-128-ctr -nopad -nosalt -k ${ENCRYPTION_KEY})
    echo "Encrypted key: ${ENCRYPTED_KEY}"
}

# Used to decrypt $ENCRYPTED_KEY
DecryptKey() {
    #	Usage: DecryptKey "ENCRYPTED_KEY" "DECRYPT_USER_UID" "ORG_ID"
    echo "${1}" | /usr/bin/openssl enc -d -base64 -aes-128-ctr -nopad -A -nosalt -k "${2}${3}"
}

install_jumpcloud_agent() {
    notify_octory "JCInstall" "installing"
    #	Remove previous installation to allow for capturing of ORG_ID
    #	Only able to get JC ORG_ID after a clean agent install
    if [[ -d /opt/jc ]]; then
        print_log "Removing previous installation of JumpCloud"
        rm -fr /opt/jc
    fi
    print_log "Downloading the jumpcloud agent"
    #	cat EOF can not be indented
    curl --silent --output /tmp/jumpcloud-agent.pkg "https://s3.amazonaws.com/jumpcloud-windows-agent/production/jumpcloud-agent.pkg" > /dev/null
    print_log "Creating the jumpcloud agent directory"
    mkdir -p /opt/jc
    print_log "Creating the jumpcloud agent bootstrap file"
    cat <<- EOF > /opt/jc/agentBootstrap.json
{
"publicKickstartUrl": "https://kickstart.jumpcloud.com:443",
"privateKickstartUrl": "https://private-kickstart.jumpcloud.com:443",
"connectKey": "$YOUR_CONNECT_KEY"
}
EOF

    print_log "Installing the jumpcloud agent"
    installer -pkg /tmp/jumpcloud-agent.pkg -target /
    notify_octory "JCInstall" "installed"
}

connect_to_jumpcloud() {
    notify_octory "Connect" "installing"
    print_log "Validating the JumpCloud Agent configuration"
    jcagent_config_path="/opt/jc/jcagent.conf"
    while [[ ! -f "${jcagent_config_path}" ]]; do
        print_log "Waiting for the JumpCloud Agent configuration file to be created"
    done
    while [[ -z "${systemKey}" ]]; do
        jcagentconfig="$(cat /opt/jc/jcagent.conf)"
        print_log "Waiting for systemKey to be set in the JumpCloud Agent configuration file"
        if [[ $jcagentconfig =~ \"systemKey\":\"[a-zA-Z0-9]{24}\" ]]; then
            systemKey="${BASH_REMATCH[*]}"
            print_log "Found systemKey: ${systemKey}"
            break
        fi
    done
    if [[ $systemKey =~ [a-zA-Z0-9]{24} ]]; then
        SYSTEMID="${BASH_REMATCH[*]}"
    fi
    #	API Key will be fetched from a file
    #	while [[ -z ${groupCheck} ]]; do
    #		timestamp=$(date -u "+%a, %d %h %Y %H:%M:%S GMT")
    #		print_log "Creating the string to sign from the request-line and the timestamp"
    #		signstr="POST /api/v2/systemgroups/${DEP_ENROLLMENT_GROUP_ID}/members HTTP/1.1\ndate: ${timestamp}"
    #		print_log "Creating the signature"
    #		signature=$(printf "$signstr" | openssl dgst -sha256 -sign /opt/jc/client.key | openssl enc -e -a | tr -d '\n')
    #		print_log "Add to the DEP enrollment group"
    #		DEPenrollmentGroupAdd=$(
    #			curl -s \
    #			-X 'POST' \
    #			-A "${USER_AGENT}" \
    #			-H 'Content-Type: application/json' \
    #			-H 'Accept: application/json' \
    #			-H "Date: ${timestamp}" \
    #			-H "Authorization: Signature keyId=\"system/${SYSTEMID}\",headers=\"request-line date\",algorithm=\"rsa-sha256\",signature=\"${signature}\"" \
    #			-d '{"op": "add","type": "system","id": "'"${SYSTEMID}"'"}' \
    #			"https://console.jumpcloud.com/api/v2/systemgroups/${DEP_ENROLLMENT_GROUP_ID}/members"
    #		)
    #
    #		print_log "DEPenrollmentGroupAdd: ${DEPenrollmentGroupAdd}"
    #		timestamp=$(date -u "+%a, %d %h %Y %H:%M:%S GMT")
    #		print_log "Create the string to sign from the request-line and the timestamp"
    #		signstr_check="GET /api/v2/systems/${SYSTEMID}/memberof HTTP/1.1\ndate: ${timestamp}"
    #		print_log "Create the signature"
    #		signature_check=$(printf "$signstr_check" | openssl dgst -sha256 -sign /opt/jc/client.key | openssl enc -e -a | tr -d '\n')
    #		print_log "Get system group memberships for the system"
    #		DEPenrollmentGroupGet=$(
    #			curl \
    #			-X 'GET' \
    #			-A "${USER_AGENT}" \
    #			-H 'Content-Type: application/json' \
    #			-H 'Accept: application/json' \
    #			-H "Date: ${timestamp}" \
    #			-H "Authorization: Signature keyId=\"system/${SYSTEMID}\",headers=\"request-line date\",algorithm=\"rsa-sha256\",signature=\"${signature_check}\"" \
    #			--url "https://console.jumpcloud.com/api/v2/systems/${SYSTEMID}/memberof"
    #		)
    #		print_log "DEPenrollmentGroupGet: $DEPenrollmentGroupGet"
    #
    #		print_log "Check if the system was added to the DEP ENROLLMENT GROUP in JumpCloud"
    #		groupCheck=$(echo "${DEPenrollmentGroupGet}" | grep "${DEP_ENROLLMENT_GROUP_ID}")
    #		print_log "groupCheck: ${groupCheck}"
    #	done
    notify_octory "Connect" "installed"
}

get_jumpcloud_security_config() {
    notify_octory "Config" "installing"
    # Delete this section because API is provided via file
    #	while [[ -z "$decrypt_user_id" ]]; do
    #		decrypt_user_id=$(dscl . -read /Users/"${DECRYPT_USER}" | grep UniqueID | cut -d " " -f 2)
    #						print_log "decrypt user id: ${decrypt_user_id}"
    #		if [[ -n "$decrypt_user_id" ]]; then
    #						print_log "Found decrypt user ${decrypt_user_id}"
    #			break
    #		fi
    #		print_log "Waiting for decrypt_user_id of user $DECRYPT_USER"
    #	done
    print_log "Gather OrgID from the jumpcloud agent config file"
    jcagentconfig="$(cat /opt/jc/jcagent.conf)"
    regex='\"ldap_domain\":\"[a-zA-Z0-9]*'
    if [[ $jcagentconfig =~ $regex ]]; then
        ORG_ID_RAW="${BASH_REMATCH[*]}"
        print_log "ORG_ID_RAW: $ORG_ID_RAW"
    fi
    ORG_ID=$(echo "${ORG_ID_RAW}" | cut -d '"' -f 4)
    print_log "ENCRYPTED_KEY: ${ENCRYPTED_KEY}, Decrypt User ID: ${DECRYPT_USER_ID}, JC Org ID: ${ORG_ID}"
    APIKEY=$(DecryptKey "${ENCRYPTED_KEY}" "${DECRYPT_USER_ID}" "${ORG_ID}")
    print_log "JumpCloud APIKEY is ${APIKEY}"
    #	If we unable to decrypt the API key, octory so display and error slide.
    if [[ -z "${APIKEY}" ]]; then
        print_log "Failed to decrypt API key"
        #		We need an Octory slide for these errors
        trigger_octory "jumpError"
    fi
    notify_octory "Config" "installed"

}

activate_user_account() {
    sec='"activated":true'
    search_step=0

    #	default value for account located
    LOCATED_ACCOUNT='False'
    while [[ "$LOCATED_ACCOUNT" == "False" ]]; do
        while [[ ! -f "${DEP_N_REGISTER_DONE}" ]]; do
            print_log "Waiting for user to fill in information in Octory."
        done
        id_type='"email"'
        employee_type=""
        company_email=""
        secret=""
        while [[ -z "${employee_type}" ]]; do
            employee_type=$(defaults read "/Library/Application Support/Octory/Resources/inputs/inputs.plist" EmployeeType 2> /dev/null)
        done

        case "${employee_type}" in
            New)
                until [[ -n "${company_email}" && -n "${secret}" ]]; do
                    company_email=$(defaults read "/Library/Application Support/Octory/Resources/inputs/inputs.plist" ceMail 2> /dev/null)
                    secret=$(defaults read "/Library/Application Support/Octory/Resources/Inputs/inputs.plist" ceSecret 2> /dev/null)
                    print_log "Waiting to retrieve user input: ${company_email}, ${secret}"
                    #					This will be added to the user search
                    injection='"employeeIdentifier":"'"${secret}"'",'

                done
                ;;
            Existing)
                while [[ -z "${company_email}" ]]; do
                    company_email=$(defaults read "/Library/Application Support/Octory/Resources/inputs/inputs.plist" ceMail 2> /dev/null)
                    print_log "Waiting to retrieve user input: ${company_email}"
                    #					This will be added to the user search
                    injection='"employeeIdentifier":null,'
                    #					injection=''
                done

                print_log "Transistion to existing hire Octory slide."
                ;;
            *)
                print_log "Employee type is ${employee_type} with lenght $(wc -c ${employee_type})"
                ;;
        esac
        #		This will be added to the user search
        #		Uncomment to prevent New Hire from using existing hire workflow
        #		injection='"employeeIdentifier":"'"${secret}"'",'

        #		rerun the search:
        #		Search for active users in JumpCloud matching the email address
        user_search=$(
            curl -s \
                -X 'POST' \
                -A "${USER_AGENT}" \
                -H 'Content-Type: application/json' \
                -H 'Accept: application/json' \
                -H "x-api-key: ${APIKEY}" \
                -d '{"filter":[{'${sec}','${injection}''${id_type}':"'"${company_email}"'"}],"fields":["username"]}' \
                "https://console.jumpcloud.com/api/search/systemusers"
        )
        print_log "curl -s \ -X 'POST' \ -A "${USER_AGENT}" \ -H 'Content-Type: application/json' \ -H 'Accept: application/json' \ -H "x-api-key: ${APIKEY}" \ -d '{"filter":[{'${sec}','${injection}''${id_type}':"'"${company_email}"'"}],"fields":["username"]}' \ "https://console.jumpcloud.com/api/search/systemusers""
        print_log "Search results: ${user_search}"
        regex='totalCount"*.*,"results"'
        if [[ ${user_search} =~ ${regex} ]]; then
            user_search_raw="${BASH_REMATCH[*]}"
        fi
        total_count=$(echo "${user_search_raw}" | cut -d ":" -f2 | cut -d "," -f1)
        print_log '{"filter":[{'${sec}','${injection}''${id_type}':"'"${company_email}"'"}],"fields":["username"]}'
        print_log "Active? totalCount ${total_count}"
        #		success criteria
        if [[ "${total_count}" == "1" ]]; then
            search_step=$((search_step + 1))
            LOCATED_ACCOUNT='True'
            computername=$(echo "${company_email}" | cut -d "@" -f 1)
            scutil --set LocalHostName "${computername}"
            scutil --set HostName "${computername}"
            scutil --set ComputerName "${computername}"

        fi
        if [[ "$total_count" != "1" ]]; then
            print_log "Account Not Found"
            rm "${DEP_N_REGISTER_DONE}" > /dev/null 2>&1
            print_log "Try searching again"
            if [[ "${employee_type}" == "New" ]]; then
                trigger_octory "jumpErrorNew"
            elif [[ "${employee_type}" == "Existing" ]]; then
                trigger_octory "jumpErrorExisting"
            fi

        fi
        print_log "Repeating search because no users were found"
    done
    #	Capture USERID
    regex='[a-zA-Z0-9]{24}'
    if [[ $user_search =~ $regex ]]; then
        USERID="${BASH_REMATCH[*]}"
        print_log "JumpCloud USERID found USERID: ${USERID}"
    else
        print_log "No JumpCloud USERID found."
        if [[ "${employee_type}" == "New" ]]; then
            trigger_octory "jumpErrorNew"
        elif [[ "${employee_type}" == "Existing" ]]; then
            trigger_octory "jumpErrorExisting"
        fi
    fi

    notify_octory "Activate" "installing"

    if [[ "${employee_type}" == "New" ]]; then
        password=$(defaults read "/Library/Application Support/Octory/Resources/Inputs/inputs.plist" cePassword)
        #		Update user password
        user_update=$(
            curl -s \
                -i \
                -X 'PUT' \
                -A "${USER_AGENT}" \
                -H 'Content-Type: application/json' \
                -H 'Accept: application/json' \
                -H "x-api-key: ${APIKEY}" \
                -d '{"password" : "'"${password}"'"}' \
                "https://console.jumpcloud.com/api/systemusers/${USERID}"
        )
        regex='HTTP/1.1 200'
        if [[ "${user_update}" =~ $regex ]]; then
            print_log "User password updated. ${user_update}"
        else
            print_log "Failed to update user password. ${user_update}"
            print_log "Password is ${password}"
            if [[ "${employee_type}" == "New" ]]; then
                trigger_octory "jumpErrorNew"
            elif [[ "${employee_type}" == "Existing" ]]; then
                trigger_octory "jumpErrorExisting"
            fi
        fi
        user_update=$(
            curl -s \
                -i \
                -X 'PUT' \
                -A "${USER_AGENT}" \
                -H 'Content-Type: application/json' \
                -H 'Accept: application/json' \
                -H "x-api-key: ${APIKEY}" \
                -d '{"mfa": {"configured": true}}' \
                "https://console.jumpcloud.com/api/systemusers/${USERID}"
        )
        regex='HTTP/1.1 200'
        if [[ "${user_update}" =~ $regex ]]; then
            print_log "User mfa requirement updated. ${user_update}"
        else
            print_log "Failed to update user mfa requirement. ${user_update}"
            if [[ "${employee_type}" == "New" ]]; then
                trigger_octory "jumpErrorNew"
            elif [[ "${employee_type}" == "Existing" ]]; then
                trigger_octory "jumpErrorExisting"
            fi

        fi

    fi
    notify_octory "Activate" "installed"
}

bind_user_to_computer() {
    trigger_octory "jumpAgain"
    notify_octory "Create" "installing"
    #	Capture current logFile
    logLinesRaw=$(wc -l /var/log/jcagent.log)
    logLines=$(echo $logLinesRaw | head -n1 | awk '{print $1;}')
    userBind=$(
        curl -s \
            -i \
            -X 'POST' \
            -A "${USER_AGENT}" \
            -H 'Accept: application/json' \
            -H 'Content-Type: application/json' \
            -H 'x-api-key: '"${APIKEY}"'' \
            -d '{ "attributes": { "sudo": { "enabled": '${admin}',"withoutPassword": false}}, "op": "add", "type": "user","id": "'"${USERID}"'"}' \
            "https://console.jumpcloud.com/api/v2/systems/${SYSTEMID}/associations"
    )

    regex='HTTP/1.1 204'
    if [[ "${userBind}" =~ $regex ]]; then
        print_log "User bound to computer. ${userBind}"
        print_log "UserID: ${USERID}, SystemID: ${SYSTEMID}"
    else
        print_log "Failed to bind user to computer. ${userBind}"
        print_log "UserID: ${USERID}, SystemID: ${SYSTEMID}"
        trigger_octory "jumpError"
    fi
    #	Check and ensure user bound to system
    userBindCheck=$(
        curl -s \
            -X 'GET' \
            -A "${USER_AGENT}" \
            -H 'Accept: application/json' \
            -H 'Content-Type: application/json' \
            -H 'x-api-key: '"${APIKEY}"'' \
            "https://console.jumpcloud.com/api/v2/systems/${SYSTEMID}/associations?targets=user"
    )
    regex=''${USERID}''
    if [[ $userBindCheck =~ $regex ]]; then
        USERID="${BASH_REMATCH[*]}"
        print_log "JumpCloud user ${USERID} bound to SYSTEMID: ${SYSTEMID}"
    else
        print_log "${USERID} : ${userBindCheck} : ${regex} error JumpCloud user not bound to system"
        trigger_octory "jumpError"
    fi
    #	NO LONGER REQUIRED AS API KEYS ARE PASSED VIA CREDS
    #	Wait to see local account takeover by the JumpCloud agent
    #	update_log=$(sed -n ''${logLines}',$p' /var/log/jcagent.log)
    #
    #
    #	accountTakeOverCheck=$(echo ${updateLog} | grep "User updates complete")
    #
    #	logoutTimeoutCounter='0'
    #
    #	while [[ -z "${accountTakeOverCheck}" ]]; do
    #		Sleep 6
    #		updateLog=$(sed -n ''${logLines}',$p' /var/log/jcagent.log)
    #		accountTakeOverCheck=$(echo ${updateLog} | grep "User updates complete")
    #		logoutTimeoutCounter=$((${logoutTimeoutCounter} + 1))
    #		if [[ ${logoutTimeoutCounter} -eq 10 ]]; then
    #			print_log "Error during JumpCloud agent local account takeover"
    #			print_log "JCAgent.log: ${updateLog}"
    #			trigger_octory "jumpError"
    #		fi
    #	done
    #
    #	print_log "Status: System Account Configured"
    #	We no longer going to use the DEP Enrollment group
    #	Remove from DEP_ENROLLMENT_GROUP and add to DEP_POST_ENROLLMENT_GROUP
    #	removeGrp=$(
    #		curl \
    #		-X 'POST' \
    #		-A "${USER_AGENT}" \
    #		-H 'Content-Type: application/json' \
    #		-H 'Accept: application/json' \
    #		-H 'x-api-key: '${APIKEY}'' \
    #		-d '{"op": "remove","type": "system","id": "'${SYSTEMID}'"}' \
    #		"https://console.jumpcloud.com/api/v2/systemgroups/${DEP_ENROLLMENT_GROUP_ID}/members"
    #	)
    #	print_log "Removing Enrollment Group $removeGrp"
    #		print_log "Removed from DEP_ENROLLMENT_GROUP_ID: $DEP_ENROLLMENT_GROUP_ID"
    addGrp=$(
        curl \
            -X 'POST' \
            -A "${USER_AGENT}" \
            -H 'Content-Type: application/json' \
            -H 'Accept: application/json' \
            -H 'x-api-key: '${APIKEY}'' \
            -d '{"op": "add","type": "system","id": "'${SYSTEMID}'"}' \
            "https://console.jumpcloud.com/api/v2/systemgroups/${DEP_POST_ENROLLMENT_GROUP_ID}/members"

    )
    print_log "Adding to Post Enrollment Group $addGrp"
    print_log "Added to from DEP_POST_ENROLLMENT_GROUP_ID: $DEP_POST_ENROLLMENT_GROUP_ID"

    notify_octory "Create" "installed"
}

apply_finishing_touches() {
    notify_octory "Finish" "installing"
    #	Add email address as account name alias
    #	Get JCAgent.log to ensure user updates have been processes on the system
    logLinesRaw=$(wc -l /var/log/jcagent.log)
    logLines=$(echo $logLinesRaw | head -n1 | awk '{print $1;}')
    groupSwitchCheck=$(sed -n ''${logLines}',$p' /var/log/jcagent.log)
    groupTakeOverCheck=$(echo ${groupSwitchCheck} | grep "User updates complete")

    #	Get current Time
    now=$(date "+%y/%m/%d %H:%M:%S")
    #	Get last line of the JumpCloud Agent
    lstLine=$(tail -1 /var/log/jcagent.log)
    regexLine='([0-9][0-9])/([0-9][0-9])/([0-9][0-9]) ([0-9][0-9]:[0-9][0-9]:[0-9][0-9])'
    if [[ $lstLine =~ $regexLine ]]; then
        #		Get the time from the agent log
        lstTime=${BASH_REMATCH[0]}
    fi
    print_log "Current System Time: $now"
    print_log "JCAgent Last Log Time: $lstTime"
    #	convert to Epoch time
    nowEpoch=$(date -j -f "%y/%m/%d %T" "${now}" +'%s')
    jclogEpoch=$(date -j -f "%y/%m/%d %T" "${lstTime}" +'%s')
    print_log "Current System Epoch Time : $nowEpoch"
    print_log "Last JCAgent Epoch Time: $jclogEpoch"
    #	get the difference in time
    epochDiff=$(((nowEpoch - jclogEpoch)))
    print_log "Difference between logs is: $epochDiff seconds"

    #	Check the JCAgent log, it should check in under 180s
    while [[ $epochDiff -le 180 ]]; do
        #		wait a second and update all the variables
        sleep 1
        groupSwitchCheck=$(sed -n ''${logLines}',$p' /var/log/jcagent.log)
        groupTakeOverCheck=$(echo ${groupSwitchCheck} | grep "Processing user updates")
        lstLine=$(tail -1 /var/log/jcagent.log)
        regexLine='([0-9][0-9])/([0-9][0-9])/([0-9][0-9]) ([0-9][0-9]:[0-9][0-9]:[0-9][0-9])'
        if [[ $lstLine =~ $regexLine ]]; then
            lstTime=${BASH_REMATCH[0]}
        fi
        jclogEpoch=$(date -j -f "%y/%m/%d %T" "${lstTime}" +'%s')
        now=$(date "+%y/%m/%d %H:%M:%S")
        nowEpoch=$(date -j -f "%y/%m/%d %T" "${now}" +'%s')
        epochDiff=$(((nowEpoch - jclogEpoch)))
        #		if the log is empty continue while loop
        if [[ -z $groupTakeOverCheck ]]; then
            print_log "Waiting for log sync, JCAgent last log was: $epochDiff seconds ago"
            print_log "JCAgent last line: $lstLine"
        else
            now=$(date "+%y/%m/%d %H:%M:%S")
            #			log found, break out of the while loop
            print_log "Log Synced! User Updates Complete $now"
            print_log "$groupTakeOverCheck"
            break
        fi
        #		if the time difference is greater than 90 seconds, restart the JumpCloud agent to begin logging again
        if [[ $epochDiff -eq 90 ]]; then
            print_log "JumpCloud not reporting local account takeover"
            print_log "Restarting JumpCloud Agent"
            launchctl stop com.jumpcloud.darwin-agent
            print_log "Waiting for JCAgent..."
            sleep 5
        fi
    done

    #	We will need to create another Octory slide for failed enrollments?
    #	Check for errors
    #	now=$(date "+%y/%m/%d %H:%M:%S")
    #	nowEpoch=$(date -j -f "%y/%m/%d %T" "${now}" +'%s')
    #	epochDiff=$(( (nowEpoch - jclogEpoch) ))
    #	if [[ $epochDiff -gt 180 ]]; then
    #		print_log "Error syncing JCAgent logs exiting Enrollment..."
    #		print_log "Command: MainTitle: Enrollment Failed"
    #		print_log "Command: MainText: Enrollment Encountered an Error"
    #		print_log "Status: Check the debug logs"
    #		sleep 10
    #		print_log "Status: Removing LaunchDaemon"
    #		print_log "Status: Quitting Enrollment"
    #		print_log "Deleting the decrypt user: $DECRYPT_USER"
    #		sysadminctl -deleteUser $DECRYPT_USER
    #		print_log "Command: Quit: "Enrollment Failed, check the debug logs in /var/tmp/""
    #		rm -- "$0"
    #		launchctl unload "/Library/LaunchDaemons/${DAEMON}"
    #	fi

    #	Check for system details and log user agent to JumpCloud
    sysSearch=$(
        curl -X GET \
            -A "${USER_AGENT}" \
            -H 'Accept: application/json' \
            -H 'Content-Type: application/json' \
            -H 'x-api-key: '${APIKEY}'' \
            "https://console.jumpcloud.com/api/systems/${SYSTEMID}"
    )

    #	Get details about the current system, log details
    regexSerial='("serialNumber":")([^"]*)(",)'
    regexName='("hostname":")([^"]*)(",)'
    regexServAcct='("hasServiceAccount":)([^"]*)(,)'
    if [[ $sysSearch =~ $regexSerial ]]; then
        sysSearchRawSerial="${BASH_REMATCH[2]}"
    fi
    if [[ $sysSearch =~ $regexName ]]; then
        sysSearchRawName="${BASH_REMATCH[2]}"
    fi
    if [[ $sysSearch =~ $regexServAcct ]]; then
        sysSearchRawServAcct="${BASH_REMATCH[2]}"
    fi

    #	Print out system info to debug log
    print_log "System Enrollment Complete:"
    print_log "=============== ENROLLMENT DETAILS =============="
    print_log "Serial Number: $sysSearchRawSerial"
    print_log "Hostname: $sysSearchRawName"
    print_log "JumpCloud Service Account Status: $sysSearchRawServAcct"
    print_log "================================================="

    print_log "Status: Enrollment Complete"
    notify_octory "Finish" "installed"
    #	trigger_octory "jumpLast"
    while [[ ! -f "${DEP_N_DONE}" ]]; do
        print_log "Waiting for user to fill in information in Octory."
    done

    get_active_user
    active_user_uid=$(id -u "${ACTIVE_USER}")
    pkill -9 -u ${active_user_uid}
    launchctl bootout user/${active_user_uid}
    print_log "ACTIVE_USER_PROCESS=$(pgrep -u ${active_user_uid}))"
    ACTIVE_USER_PROCESS=$(pgrep -u ${active_user_uid})
    while [[ "${ACTIVE_USER_PROCESS}" != "" ]]; do
        ACTIVE_USER_PROCESS=$(pgrep -u "${active_user_uid}")
        print_log "Waiting for ${ACTIVE_USER} processes to terminate. ${ACTIVE_USER_PROCESS}"
    done
    print_log "Waiting for ${ACTIVE_USER} user to logout... "
    wait_for_process "exit" "Finder"
    #	Once the Finder proces has exited, start the next process of the automated device enrollment
    print_log "Configuring com.foursquare.app_provisioning.plist to start"
    plutil -replace RunAtLoad -bool true /Library/LaunchDaemons/com.foursquare.app_provisioning.plist
    plutil -replace Disabled -bool false /Library/LaunchDaemons/com.foursquare.app_provisioning.plist
    print_log "Loading com.foursquare.app_provisioning.plist launch daemon"
    launchctl load /Library/LaunchDaemons/com.foursquare.app_provisioning.plist

    #	final steps to check
    #	this will initially fail at the end of the script, if we remove the welcome user
    #	the LaunchDaemon will be running as user null. However on next run, the script
    #	will run as root and should have access to remove the launch daemon and remove
    #	this script. The LaunchDaemon process with status 127 will remain on the system
    #	until reboot, it will be not be called again after reboot.
    #	Delete enrollment users
    if [[ $DELETE_ENROLLMENT_USERS == true ]]; then
        #		wait until welcome user is logged out
        print_log "Testing if ${ENROLLMENT_USER} user is logged out"
        get_active_user
        if [[ "${ACTIVE_USER}" == "${ENROLLMENT_USER}" ]]; then
            print_log "Logged in user is: ${ACTIVE_USER}, waiting until logout to continue"
            wait_for_processs "exit" "Finder"
        fi
        #		given the case that the enrollment user was logged in previously, recheck the active user
        get_active_user
        print_log "Logged in user is: ${ACTIVE_USER}"
        if [[ "${ACTIVE_USER}" == "" || "${ACTIVE_USER}" != "${ENROLLMENT_USER}" ]]; then
            #			delete the enrollment and decrypt user
            print_log "Deleting the first enrollment user $ENROLLMENT_USER"
            #			Comment this during testing
            #			Hide the welcome account from the login screen
            #			print_log "Executing hide: $(/usr/bin/dscl . create /Users/welcome IsHidden 1)
            print_log "Executing delete: $(/usr/bin/dscl . -delete /Users/"${ENROLLMENT_USER}")"
            print_log "Executing delete: $(sysadminctl -deleteUser $ENROLLMENT_USER)"

            #			print_log "Deleting the decrypt user: $DECRYPT_USER"
            #			Comment this during testing
            #			print_log "Executing delete: $(/usr/bin/dscl . -delete /Users/"${DECRYPT_USER}")"
            #			print_log "Executing delete: $(sysadminctl -deleteUser $DECRYPT_USER)"
        fi
    fi
    #	Clean up steps
    #	Remove the LaunchDaemon file if it exists
    if [[ -f "/Library/LaunchDaemons/${DAEMON}" ]]; then
        #	Comment this during testing
        rm -rf "/Library/LaunchDaemons/${DAEMON}"
        print_log "Status: LaunchDaemon Removed /Library/LaunchDaemons/${DAEMON}"
    else
        print_log "Warning: Could not find/ remove LaunchDaemon /Library/LaunchDaemons/${DAEMON}"
    fi
}

clear_previous_input() {
    if [[ -f "${DEP_N_REGISTER_DONE}" ]]; then
        print_log "Removing the Octory registration done file."
        rm -f "${DEP_N_REGISTER_DONE}"
    fi
    if [[ -f "${DEP_N_DONE}" ]]; then
        print_log "Removing the Octory registration done file."
        rm -f "${DEP_N_DONE}"
    fi
    if [[ -d "/Library/Application Support/Octory/Resources/Inputs" ]]; then
        print_log "Removing previous Octory inputs.plist file"
        rm -f "/Library/Application Support/Octory/Resources/Inputs/inputs.plist"

        get_active_user
        print_log "Changing ownership of the Octory Inputs directory to ${ACTIVE_USER}"
        chown "${ACTIVE_USER}" "/Library/Application Support/Octory/Resources/Inputs"
    fi
}

provision_enrollment_user() {
    print_log "Provisioning the ${ENROLLMENT_USER} account"
    while [[ -z "$(dscl . read /Users/${ENROLLMENT_USER} RealName 2> /dev/null)" ]]; do
        print_log "Waiting for ${ENROLLMENT_USER} account creation"
    done

    print_log "${ENROLLMENT_USER} real name is $(dscl . read /Users/${ENROLLMENT_USER} RealName 2> /dev/null)"

    while [[ "$(dscl . read /Users/${ENROLLMENT_USER} RealName 2> /dev/null)" != $(cut -d';' -f 2 /var/run/JumpCloud-SecureToken-Creds.txt) ]]; do
        print_log "Updating ${ENROLLMENT_USER} display name to Password is $(cut -d';' -f 2 /var/run/JumpCloud-SecureToken-Creds.txt)"
        dscl . create /Users/"{$ENROLLMENT_USER}" RealName "Password is $(cut -d';' -f 2 /var/run/JumpCloud-SecureToken-Creds.txt)"
    done
    print_log "${ENROLLMENT_USER} real name is $(dscl . read /Users/"${ENROLLMENT_USER}" RealName 2> /dev/null)"

}
main() {
    trap stop_caffeinate EXIT
    runtime_vars

    start_caffeinate
    set_datetime
    #provision_enrollment_user
    wait_for_process "launch" "Finder"

    clear_previous_input
    start_octory "account_provisioning.plist"
    wait_for_octory_helper

    install_jumpcloud_agent
    connect_to_jumpcloud
    get_jumpcloud_security_config

    activate_user_account
    bind_user_to_computer
    apply_finishing_touches
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
