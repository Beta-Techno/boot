#!/usr/bin/env bash
set -Eeuo pipefail

# First-boot provisioning script
# Runs the existing working anvil install process

LOGFILE="/var/log/first-boot.log"
exec 1> >(tee -a "$LOGFILE")
exec 2>&1

echo "========================================"
echo "First Boot Provisioning Started"
echo "Time: $(date)"
echo "========================================"

# Configuration (can be overridden via environment variables)
ANVIL_INSTALL_URL="${ANVIL_INSTALL_URL:-https://raw.githubusercontent.com/Beta-Techno/anvil/main/install.sh}"
TAGS="${TAGS:-all}"
ANSIBLE_ARGS="${ANSIBLE_ARGS:---skip-tags docker_desktop}"

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

check_network() {
    log_info "Checking network connectivity..."
    if ! ping -c 1 github.com &>/dev/null; then
        log_error "No network connectivity"
        return 1
    fi
    log_info "Network OK"
}

run_anvil_install() {
    log_info "Running anvil installation..."
    log_info "URL: $ANVIL_INSTALL_URL"
    log_info "TAGS: $TAGS"
    log_info "ANSIBLE_ARGS: $ANSIBLE_ARGS"

    # Run the existing working command
    curl -fsSL "$ANVIL_INSTALL_URL" | \
        TAGS="$TAGS" ANSIBLE_ARGS="$ANSIBLE_ARGS" bash

    if [ $? -eq 0 ]; then
        log_info "Anvil installation completed successfully"
        return 0
    else
        log_error "Anvil installation failed"
        return 1
    fi
}

main() {
    log_info "Starting first-boot provisioning"

    # Check prerequisites
    check_network || exit 1

    # Run anvil (your existing working flow)
    run_anvil_install || exit 1

    log_info "First-boot provisioning completed successfully"
    echo "========================================"
    echo "First Boot Complete"
    echo "Time: $(date)"
    echo "========================================"
    echo ""
    echo "System is ready to use!"
    echo "Check /var/log/first-boot.log for details"
}

main "$@"
