#!/bin/bash
if [[ -r "$(pwd)"/../build_pkg.sh ]]; then
    source "$(pwd)"/../build_pkg.sh
else
    echo "Could not load build_pkg.sh script"
    exit 1
fi

check_scripts_directory() {
    if [[ ! -f scripts/postinstall ]]; then
        print_log "Download postinstall file from https://my.1password.com/vaults/oc3jcx4rzdhyl3eogkcnlrsvga/allitems/zh27keuotjrtr2fzp346kkstia and copy it to scripts/postinstall"
    fi
    if [[ ! -f scripts/postupgrade ]]; then
        print_log "Download postupgrade file from https://start.1password.com/open/i?a=BJLZ3YS74VHYDJT36OMIGJQUVM&h=my.1password.com&i=vw4nluvmrlgv3q5qqhupc6ruda&v=oc3jcx4rzdhyl3eogkcnlrsvga and copy it to script/postupgrade"
    fi

    if [[ ! -f scripts/postinstall || ! -f scripts/postupgrade ]]; then
        exit 1
    fi
}

IDENTIFIER="com.foursquare.automatedonboarding_passwordpoc"
#cp -r ../Octory-2.2.0-with-agent/ payload

main() {
    trap clean_up EXIT
    check_scripts_directory
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
