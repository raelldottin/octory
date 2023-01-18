#!/bin/zsh

################################################################################################
# Created by Nicholas McDonald | se@kandji.io | Kandji, Inc. | Solutions Engineering
################################################################################################
# Created on 11/24/2020
# Updated on 09/24/2021 - David Larrea and Matt Wilson
################################################################################################
# Software Information
################################################################################################
# This script checks the architecture of a macOS Device, if the Mac is running on Apple Silicon
# The script then checks if Rosetta is installed, and if not, installs it silently
#
# Tested on the following macOS versions
#
#   - 11.6
#   - 11.5.1
#   - 11.4
#   - 11.3
#   - 11.2.3
#
################################################################################################
# License Information
################################################################################################
# Copyright 2020 Kandji, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
# to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#
################################################################################################

# Version
VERSION="1.1.0"

# Determine the processor brand
processorBrand=$(/usr/sbin/sysctl -n machdep.cpu.brand_string)

if [[ "${processorBrand}" = *"Apple"* ]]; then
    echo "Apple Processor is present..."
else
    echo "Apple Processor is not present... rosetta not needed"
    exit 0
fi

# Rosetta Status
checkRosettaStatus=$(/bin/launchctl list | /usr/bin/grep "com.apple.oahd-root-helper")

# Rosetta Folder location
# Condition to check to see if the Rosetta folder exists. This check was added because the
# Rosetta2 service is already running in macOS versions 11.5 and greater without Rosseta2 actually
# being instaslled.
RosettaFolder="/Library/Apple/usr/share/rosetta"

if [[ -e "${RosettaFolder}" && "${checkRosettaStatus}" != "" ]]; then
    echo "Rosetta Folder exists and Rosetta Service is running... exiting"
    exit 0
else
    echo "Rosetta Folder does not exist or Rosetta service is not running... installing Rosetta"
fi

# Installs Rosetta
/usr/sbin/softwareupdate --install-rosetta --agree-to-license

# Checks the outcome of the Rosetta install
if [[ $? -eq 0 ]]; then
    echo "Rosetta installed... exiting"
    exit 0
else
    echo "Rosetta install failed..."
    exit 1
fi

exit 0