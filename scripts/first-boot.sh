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
ANVIL_CLI_INSTALL_URL="${ANVIL_CLI_INSTALL_URL:-https://raw.githubusercontent.com/Beta-Techno/anvil/main/install.sh}"
ANVIL_CLI_BINARY_URL="${ANVIL_CLI_BINARY_URL:-https://github.com/Beta-Techno/anvil/releases/latest/download/anvil-linux-amd64}"
ANVIL_CLI_INSTALL_DIR="${ANVIL_CLI_INSTALL_DIR:-/usr/local/bin}"

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

check_network() {
    log_info "Checking network connectivity..."
    if ! curl -fsSL https://github.com &>/dev/null; then
        log_error "Unable to reach github.com via HTTPS"
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

setup_autostart_prompt() {
    log_info "Configuring first-login prompt"
    local home_dir="/home/deploy"
    mkdir -p "$home_dir/.local/bin" "$home_dir/.config/autostart"
    cat > "$home_dir/.local/bin/anvil-first-login.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
SENTINEL="$HOME/.config/anvil/first-login-complete"
mkdir -p "$(dirname "$SENTINEL")"
if [ -f "$SENTINEL" ]; then
    exit 0
fi
nohup gnome-terminal -- bash -lc 'echo "========================================"; \
  echo "Anvil CLI installed."; \
  echo "Enter your age secret key when prompted to begin provisioning."; \
  echo "========================================"; \
  if anvil up; then \
    touch ~/.config/anvil/first-login-complete; \
  fi; \
  echo "Anvil run finished (exit $?). Press Enter to close."; \
  read' >/dev/null 2>&1 &
exit 0
EOS
    chmod +x "$home_dir/.local/bin/anvil-first-login.sh"

    cat > "$home_dir/.config/autostart/anvil-first-login.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Anvil Provisioning
Exec=/home/deploy/.local/bin/anvil-first-login.sh
X-GNOME-Autostart-Delay=5
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;Unity;
EOF

    chown -R deploy:deploy "$home_dir/.local/bin" "$home_dir/.config/autostart"
}

main() {
    log_info "Starting first-boot provisioning"

    # Check prerequisites
    check_network || exit 1

    install_cli || exit 1
    setup_autostart_prompt || true

    log_info "First-boot provisioning completed successfully"
    echo "========================================"
    echo "First Boot Complete"
    echo "Time: $(date)"
    echo "========================================"
    echo ""
    echo "System is ready. Please log in and follow the terminal prompt to run 'anvil up'."
    echo "Logs: /var/log/first-boot.log"
}

main "$@"
