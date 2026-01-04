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
    local homeDir="/home/deploy"
    mkdir -p \
      "$homeDir/.local/bin" \
      "$homeDir/.config/anvil" \
      "$homeDir/.config/systemd/user" \
      "$homeDir/.config/systemd/user/paths.target.wants"

    cat > "$homeDir/.local/bin/anvil-first-login.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
SENTINEL="$HOME/.config/anvil/first-login-complete"
mkdir -p "$(dirname "$SENTINEL")"
if [ -f "$SENTINEL" ]; then
    exit 0
fi
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    exit 0
fi
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
for _ in {1..90}; do
    if gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
term_cmd=()
term_label="terminal"
if command -v gnome-terminal >/dev/null 2>&1; then
    term_cmd=(gnome-terminal --wait --)
    term_label="gnome-terminal"
elif command -v x-terminal-emulator >/dev/null 2>&1; then
    term_cmd=(x-terminal-emulator -e)
    term_label="x-terminal-emulator"
else
    command -v notify-send >/dev/null 2>&1 && notify-send "Anvil" "Open a terminal and run: anvil up"
    exit 0
fi
LOG="$HOME/.config/anvil/anvil-up.log"
mkdir -p "$(dirname "$LOG")"
if ! "${term_cmd[@]}" bash --noprofile --norc -lc "echo '========================================'; \
  echo 'Anvil provisioning'; \
  echo 'Paste AGE key when prompted.'; \
  echo 'Logs: $LOG'; \
  if anvil up 2>&1 | tee -a '$LOG'; then \
    touch '$SENTINEL'; \
    echo 'SUCCESS. Sentinel written.'; \
  else \
    echo 'FAILED. Sentinel not written.'; \
  fi; \
  read -rp 'Press Enter to close...';" >/dev/null 2>&1; then
  echo "[anvil-first-login] Failed to launch $term_label. Run 'anvil up' manually." | systemd-cat -t anvil-first-login || true
fi
EOS
    chmod +x "$homeDir/.local/bin/anvil-first-login.sh"

    cat > "$homeDir/.config/systemd/user/anvil-first-login.service" <<'EOF'
[Unit]
Description=Anvil first-login prompt
After=graphical-session.target
Wants=graphical-session.target
ConditionPathExists=/var/lib/first-boot-complete
ConditionPathExists=!%h/.config/anvil/first-login-complete

[Service]
Type=oneshot
ExecStart=%h/.local/bin/anvil-first-login.sh
EOF

cat > "$homeDir/.config/systemd/user/anvil-first-login.path" <<'EOF'
[Unit]
Description=Trigger Anvil prompt when first-boot completes
After=graphical-session.target
Wants=graphical-session.target
ConditionPathExists=!%h/.config/anvil/first-login-complete

[Path]
PathExists=/var/lib/first-boot-complete
Unit=anvil-first-login.service

[Install]
WantedBy=paths.target
EOF

    ln -sf ../anvil-first-login.path "$homeDir/.config/systemd/user/paths.target.wants/anvil-first-login.path"
    chown -R deploy:deploy "$homeDir/.local" "$homeDir/.config" 2>/dev/null || true
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
