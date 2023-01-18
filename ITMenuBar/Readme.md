# [ITMenuBar](https://github.com/foursquare/it/tree/master/octory/ITMenuBar)
Is a macOS menu bar for display system information on a FSQ macOS
device.

It uses Octory which is a highly customizable macOS application for displaying
information and interacting with users on macOS. Its application is located in
/Library/Application Support/Octory. The Octory documentation is located here:
https://documents.octory.io/.
- [Readme.md](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/Readme.md)
- [build](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/build)
- [build_pkg.sh](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/build_pkg.sh)
- [payload](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/payload)
- [resources](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/resources)
- [scripts](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/resources)

## Build Instructions
```console
sudo ./build_pkg.sh "ITMenuBar"
```

## [build](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/build)
Build directory containing your recent package build output files

## [build_pkg.sh](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/build_pkg.sh)
Build script for building your package

## [payload](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/payload)
Payload directory containing the root directory for package 
- [ITMenuBar.plist](https://github.com/foursquare/it/blob/master/octory/ITMenuBar/payload/Library/Application%20Support/Octory/ITMenuBar.plist): Octory configuration file
- [License.json](https://github.com/foursquare/it/blob/master/octory/ITMenuBar/payload/Library/Application%20Support/Octory/License.json): Octory license file
- [Octory.app](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/payload/Library/Application%20Support/Octory/Octory.app): Octory application bundle
- [fsq_menubar.png](https://github.com/foursquare/it/blob/master/octory/ITMenuBar/payload/Library/Application%20Support/Octory/Resources/Images/fsq_menubar.png): Octory custom menu bar icon
- [current_time.sh](https://github.com/foursquare/it/blob/master/octory/ITMenuBar/payload/Library/Application%20Support/Octory/Resources/Scripts/current_time.sh): Script to get current Unix epoch time
- [human_readable_uptime.sh](https://github.com/foursquare/it/blob/master/octory/ITMenuBar/payload/Library/Application%20Support/Octory/Resources/Scripts/human_readable_uptime.sh): Script to display computer uptime in human readable format
- [uptime_threshold.sh](https://github.com/foursquare/it/blob/master/octory/ITMenuBar/payload/Library/Application%20Support/Octory/Resources/Scripts/uptime_threshold.sh): Script to get unix epoch time that is two weeks after boot time
- [com.foursquare.itmenubar.plist](https://github.com/foursquare/it/blob/master/octory/ITMenuBar/payload/Library/LaunchAgents/com.foursquare.itmenubar.plist): Launch Agent to launch the Octory application with its configuration file
- [com.amaris.octory.helper.plist](https://github.com/foursquare/it/blob/master/octory/ITMenuBar/payload/Library/LaunchDaemons/com.amaris.octory.helper.plist): Launch Daemon  to launch the Octory helper applications 
- [com.amaris.octory.helper](https://github.com/foursquare/it/blob/master/octory/ITMenuBar/payload/Library/PrivilegedHelperTools/com.amaris.octory.helper): Octory helper binary

## [resources](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/resources)
Resources directory contains the requirements plist which allows you specify build requirements for your package

## [scripts](https://github.com/foursquare/it/tree/master/octory/ITMenuBar/resources)
Scripts directory containing scripts for your package



