#!/bin/zsh
# removeHelper v1.0.0
# Amaris (Alexis Bridoux)

/bin/launchctl unload /Library/LaunchDaemons/com.amaris.octory.helper.plist
/bin/rm /Library/LaunchDaemons/com.amaris.octory.helper.plist
/bin/rm /Library/PrivilegedHelperTools/com.amaris.octory.helper