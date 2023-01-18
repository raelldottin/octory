#!/bin/bash
if [[ -r "$(pwd)"/../build_pkg.sh ]]; then
    source "$(pwd)"/../build_pkg.sh
else
    echo "Could not load build_pkg.sh script"
    exit 1
fi

IDENTIFIER="com.foursquare.osupgrade"
get_parent_directory
get_active_user
revisioncount=$(sudo -i -u "$ACTIVE_USER" git -C "$(pwd)" log --oneline | wc -l | tr -d ' ')
projectversion=$(sudo -i -u "$ACTIVE_USER" git -C "$(pwd)" describe --tags --long)
cleanversion=${projectversion%%-*}
VERSION="$cleanversion.$revisioncount"

main() {
    trap clean_up EXIT
    get_parent_directory
    usage "${1}" "${2}"
    start_caffeinate
    pre_packaging
    create_component_plist "${1}"
    build_package "${1}"
    create_distribution_plist "${1}"
    create_product_archive "${1}"
    signed_package "${1}"
    post_packaging
    deploy_to_vm "${1}" "${2}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "${1}" "${2}"
fi
