#!/bin/bash
IDENTITY="3rd Party Mac Developer Installer: Foursquare Labs, Inc. (ABUPJG7JQ3)"
ACTIVE_USER=""
PARENT_DIR=""
VERSION=""

get_active_user() {
    ACTIVE_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
    echo "Collected details on current logged in user: $ACTIVE_USER"
}

runas_active_user() {
    get_active_user
    launchctl "asuser" "$(id -u "$ACTIVE_USER")" sudo -iu "$ACTIVE_USER" "$@"
    echo "Running \"${*}\" as $ACTIVE_USER"
}

get_parent_directory() {
    PARENT_DIR=$(unset CDPATH && cd "$(dirname "$0")" && echo "$PWD")
    echo "Collected parent working directory: $PARENT_DIR"
}

usage() {
    get_parent_directory
    get_active_user
    if [[ "$(id -u)" != "0" ]]; then
        echo "Please run this script as root"
        exit 1
    elif [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: $(basename "$0") [package name] [package identifier]"
        exit 1
    elif [[ -z "$IDENTITY" ]]; then
        print_log "No identity specified for creating a signed package"
        exit 1
    elif [[ -z "$PARENT_DIR" ]]; then
        echo "No parent directory specified"
        exit 1
    elif [[ -z "$VERSION" ]]; then
        echo "No version specified"
        exit 1
    elif [[ -z "$ACTIVE_USER" ]]; then
        echo "No active user found"
        exit 1
    fi
}

pre_packaging() {
    echo "Performing prepackaging tasks."
    get_parent_directory
    if [[ ! -d "$PARENT_DIR"/nopayload ]]; then
        mkdir -p "$PARENT_DIR"/nopayload
    fi
    if [[ ! -x "$PARENT_DIR"/scripts/postinstall ]]; then
        echo "Please run the following command: chmod +x $PARENT_DIR/scripts/postinstall"
        exit 1
    fi
}

sign_package() {
    runas_active_user "productsign" "--sign" "$IDENTITY" "$PARENT_DIR/../build/$1-$VERSION.pkg" "$PARENT_DIR/../build/$1-signed-$VERSION.pkg"
    if [[ $? -ne 0 ]]; then
        print_log "Failed to sign the package"
        exit 1
    else
        if [[ -f "$PARENT_DIR/build/$1-signed-$VERSION.pkg" ]]; then
            print_log "Signed package created: $PARENT_DIR/../build/$1-signed-$VERSION.pkg"
        fi
    fi
}

main() {
    get_active_user
    REVISIONCOUNT=$(sudo -i -u "$ACTIVE_USER" git -C "$(pwd)" log --oneline | wc -l | tr -d ' ')
    PROJECTVERSION=$(sudo -i -u "$ACTIVE_USER" git -C "$(pwd)" describe --tags --long)
    CLEANVERSION=${PROJECTVERSION%%-*}
    VERSION="$CLEANVERSION.$REVISIONCOUNT"
    usage "$1" "$2"
    get_parent_directory
    pre_packaging
    pkgbuild --identifier "$2" --root "$PARENT_DIR"/nopayload --scripts "$PARENT_DIR"/scripts "$PARENT_DIR"/../build/"$1"-"$VERSION".pkg
    sign_package "$1"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "${1}" "${2}"
fi
