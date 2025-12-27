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
ANVIL_CLI_INSTALL_URL="${ANVIL_CLI_INSTALL_URL:-https://raw.githubusercontent.com/Beta-Techno/anvil/main/scripts/install-anvil-cli.sh}"
ANVIL_CLI_BINARY_URL="${ANVIL_CLI_BINARY_URL:-https://github.com/Beta-Techno/anvil/releases/latest/download/anvil-linux-amd64}"
ANVIL_CLI_INSTALL_DIR="${ANVIL_CLI_INSTALL_DIR:-/usr/local/bin}"
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

install_cli() {
    log_info "Installing Anvil CLI (binary: $ANVIL_CLI_BINARY_URL)"
    tmp_script="$(mktemp)"
    curl -fsSL "$ANVIL_CLI_INSTALL_URL" -o "$tmp_script"
    chmod +x "$tmp_script"
    INSTALL_DIR="$ANVIL_CLI_INSTALL_DIR" BINARY_URL="$ANVIL_CLI_BINARY_URL" bash "$tmp_script"
    rm -f "$tmp_script"
}

main() {
    log_info "Starting first-boot provisioning"

    # Check prerequisites
    check_network || exit 1

    install_cli || exit 1

    log_info "Anvil CLI installed. Log in and run 'anvil up' to start provisioning."
    touch /var/lib/first-boot-complete

    log_info "First-boot provisioning completed successfully (CLI installed, awaiting user run)"
    echo "========================================"
    echo "First Boot Complete"
    echo "Time: $(date)"
    echo "========================================"
    echo ""
    echo "System is ready to use!"
    echo "Check /var/log/first-boot.log for details"
}

main "$@"
