#!/bin/bash

PARENT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${PARENT_DIR}/stdfunc.sh"

print_log "OS Update deferred." >> /var/tmp/os_update_deferral.log
