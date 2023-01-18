#!/bin/zsh
mylogpath=.
mylog=$mylogpath/myawesomlog-$(date +%Y%m%d-%H%M).log

[[ ! -d ${mylogpath} ]]
mkdir -p $mylogpath

set -xv
exec 1> $mylog 2>&1

# Upload our log using API
jss_user='svcjamf-fileuploads'
echo $jss_user
jss_pass='9JgNquNMGh!7N.AJzmUwvEdVHTBsB.L-7'
echo $jss_pass

jss_url=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url | sed s'/.$//')
echo $jss_url

# get computer serial number to lookup the JSS ID of the computer
serial=$(system_profiler SPHardwareDataType | awk '/Serial\ Number\ \(system\)/ {print $NF}')
echo $serial

# get ID of computer
JSS_ID=$(curl -H "Accept: text/xml" -sfku "${jss_user}:${jss_pass}" "${jss_url}/JSSResource/computers/serialnumber/${serial}/subset/general"
#| xpath /computer/general/id[1] | awk -F'>|<' '{print $3}')
echo $JSS_ID

# upload the log to the comptuer record

#curl -sku $jss_user:$jss_pass $jss_url/JSSResource/fileuploads/computers/id/$JSS_ID -F name=@${mylog} -X POST
