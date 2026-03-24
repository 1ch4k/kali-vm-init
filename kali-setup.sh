#!/usr/bin/env zsh
# =============================================================================
#  kali-setup.sh — Fresh Kali VM bootstrapper
#  Shell: zsh (default on modern Kali)
#  Installs: full system update · Python venv · GVM · Vulnscan · CopyQ
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { print -P "${GREEN}[+]${RESET} $*" }
info()    { print -P "${CYAN}[i]${RESET} $*" }
warn()    { print -P "${YELLOW}[!]${RESET} $*" }
section() {
    print -P "\n${BOLD}${CYAN}══════════════════════════════════════${RESET}"
    print -P "${BOLD}${CYAN}  $*${RESET}"
    print -P "${BOLD}${CYAN}══════════════════════════════════════${RESET}"
}

# ── Detect shell config file ──────────────────────────────────────────────────
SHELL_RC="$HOME/.zshrc"

# ── Paths ─────────────────────────────────────────────────────────────────────
TOOLS_DIR="$HOME/tools"
VENV_DIR="$HOME/.venvs/pentest"
VULNSCAN_DIR="$TOOLS_DIR/vulnscan"
GVM_DIR="$TOOLS_DIR/gvm"
BIN_DIR="$HOME/.local/bin"

# ── Ensure local bin is in PATH ───────────────────────────────────────────────
mkdir -p "$BIN_DIR"
if ! grep -q "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    export PATH="$BIN_DIR:$PATH"
fi

# =============================================================================
section "1 · Full system update"
# =============================================================================
log "Running full system update..."
sudo apt update

log "Running full-upgrade..."
sudo apt full-upgrade -y

log "Removing unused packages..."
sudo apt autoremove -y

log "System is up to date."

# =============================================================================
section "2 · Base dependencies"
# =============================================================================
log "Installing base packages..."
sudo apt install -y \
    python3 python3-pip python3-venv python3-dev \
    git curl wget unzip build-essential \
    libssl-dev libffi-dev \
    nmap \
    zsh

log "Base packages installed."

# =============================================================================
section "3 · Python virtual environment"
# =============================================================================
mkdir -p "$(dirname "$VENV_DIR")"

if [[ -d "$VENV_DIR" ]]; then
    warn "Venv already exists at $VENV_DIR — skipping creation."
else
    log "Creating Python venv at $VENV_DIR ..."
    python3 -m venv "$VENV_DIR"
    log "Venv created."
fi

source "$VENV_DIR/bin/activate"

log "Upgrading pip inside venv..."
pip install --upgrade pip setuptools wheel -q

log "Installing pentest Python libraries..."
pip install -q \
    requests \
    paramiko \
    impacket \
    python-nmap \
    scapy \
    colorama \
    pwntools \
    gvm-tools

log "Python venv ready at: $VENV_DIR"
info "Activate manually with:  source $VENV_DIR/bin/activate"

# =============================================================================
section "4 · GVM / OpenVAS tools"
# =============================================================================
mkdir -p "$GVM_DIR"

log "Checking for system GVM daemon (gvmd)..."
if command -v gvmd &>/dev/null; then
    info "gvmd found: $(gvmd --version 2>/dev/null | head -1)"
else
    warn "gvmd not found. Installing Greenbone OpenVAS stack..."
    sudo apt install -y \
        gvm openvas gvmd gsa gsad \
        2>/dev/null || warn "Some GVM packages may not be available — check your Kali repo."

    log "Running gvm-setup (this can take several minutes)..."
    if command -v gvm-setup &>/dev/null; then
        sudo gvm-setup 2>&1 | tee "$GVM_DIR/setup.log" \
            || warn "gvm-setup finished with warnings — check $GVM_DIR/setup.log"
    fi
fi

cat > "$GVM_DIR/gvm-connect.sh" << 'EOF'
#!/usr/bin/env zsh
GVM_SOCKET="/run/gvmd/gvmd.sock"
if [[ ! -S "$GVM_SOCKET" ]]; then
    echo "[!] GVM socket not found. Start GVM with:  sudo gvm-start"
    exit 1
fi
echo "[+] Connecting to GVM via $GVM_SOCKET"
gvm-cli --gmp-username admin socket --socketpath "$GVM_SOCKET" "$@"
EOF
chmod +x "$GVM_DIR/gvm-connect.sh"
ln -sf "$GVM_DIR/gvm-connect.sh" "$BIN_DIR/gvm-connect"
log "GVM connect helper linked → 'gvm-connect'"

# =============================================================================
section "5 · Vulnscan — Nmap NSE script"
# =============================================================================
if [[ -d "$VULNSCAN_DIR/.git" ]]; then
    warn "Vulnscan already cloned — pulling latest..."
    git -C "$VULNSCAN_DIR" pull --ff-only
else
    log "Cloning Vulnscan into $VULNSCAN_DIR ..."
    git clone --depth=1 https://github.com/scipag/vulscan.git "$VULNSCAN_DIR"
fi

NMAP_SCRIPTS_DIR="/usr/share/nmap/scripts"
VULSCAN_LINK="$NMAP_SCRIPTS_DIR/vulscan"

if [[ -L "$VULSCAN_LINK" ]]; then
    info "Vulscan symlink already exists at $VULSCAN_LINK"
elif [[ -d "$VULSCAN_LINK" ]]; then
    warn "Vulscan directory already at $NMAP_SCRIPTS_DIR — skipping symlink."
else
    log "Creating symlink: $VULSCAN_LINK → $VULNSCAN_DIR"
    sudo ln -s "$VULNSCAN_DIR" "$VULSCAN_LINK"
fi

log "Updating Nmap script database..."
sudo nmap --script-updatedb -q 2>/dev/null || warn "nmap --script-updatedb failed (non-fatal)"

info "Vulnscan ready. Example usage:"
info "  sudo nmap -sV --script=vulscan/vulscan.nse <target>"

# =============================================================================
section "6 · CopyQ — GUI clipboard manager (Win+V opens history)"
# =============================================================================
#
#  Ctrl+C  = copy   (unchanged)
#  Ctrl+V  = paste  (unchanged)
#  Win+V   = open CopyQ history picker
#
log "Installing CopyQ..."
if ! command -v copyq &>/dev/null; then
    sudo apt install -y copyq 2>/dev/null \
        || { warn "CopyQ not in apt — trying flatpak...";
             sudo apt install -y flatpak 2>/dev/null;
             sudo flatpak remote-add --if-not-exists flathub \
                 https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null;
             sudo flatpak install -y flathub com.github.hluk.copyq 2>/dev/null \
                 || warn "Could not auto-install CopyQ. Run manually: sudo apt install copyq"; }
else
    info "CopyQ already installed."
fi

if command -v copyq &>/dev/null; then
    log "CopyQ installed: $(copyq --version 2>/dev/null | head -1)"

    # Autostart on login
    AUTOSTART_DIR="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_DIR/copyq.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=CopyQ
Comment=Clipboard manager with history
Exec=copyq
Icon=copyq
Terminal=false
Categories=Utility;
X-GNOME-Autostart-enabled=true
EOF
    log "CopyQ set to autostart on login."

    # Global shortcut: Win+V (meta+v) → open clipboard history
    COPYQ_CFG_DIR="$HOME/.config/copyq"
    mkdir -p "$COPYQ_CFG_DIR"
    COPYQ_CFG="$COPYQ_CFG_DIR/copyq.conf"

    if [[ ! -f "$COPYQ_CFG" ]] || ! grep -q "toggle" "$COPYQ_CFG" 2>/dev/null; then
        cat > "$COPYQ_CFG" << 'EOF'
[General]
autostart=true
maxitems=200
savedelay=5000

[GlobalShortcuts]
toggle=meta+v
EOF
        log "Global shortcut configured: Win+V → open CopyQ history"
    else
        info "CopyQ config already exists — shortcut not overwritten."
        info "To change it: CopyQ → File → Preferences → Global Shortcuts"
    fi

    # Start CopyQ now
    if ! pgrep -x copyq &>/dev/null; then
        copyq &
        disown
        log "CopyQ started in background."
    else
        info "CopyQ is already running."
    fi
else
    warn "CopyQ could not be installed. Run manually: sudo apt install copyq"
fi

# =============================================================================
section "7 · Zsh aliases"
# =============================================================================
if ! grep -q "# kali-vm-init aliases" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << EOF

# kali-vm-init aliases
alias gvmc='gvm-connect'
alias update-tools='cd $TOOLS_DIR && for d in */; do [[ -d "\$d/.git" ]] && echo "→ \$d" && git -C "\$d" pull --ff-only; done'
EOF
    log "Aliases added to $SHELL_RC"
fi

# =============================================================================
section "Setup complete"
# =============================================================================
print ""
print -P "${BOLD}${GREEN}  Quick reference:${RESET}"
print ""
print -P "  ${CYAN}source ~/.venvs/pentest/bin/activate${RESET}                Activate Python venv"
print -P "  ${CYAN}Ctrl+C / Ctrl+V${RESET}                                     Copy and paste (unchanged)"
print -P "  ${CYAN}Win+V${RESET}                                                Open CopyQ clipboard history"
print -P "  ${CYAN}sudo nmap -sV --script=vulscan/vulscan.nse <host>${RESET}   Run Vulscan"
print -P "  ${CYAN}gvm-connect  (alias: gvmc)${RESET}                          Connect to GVM socket"
print -P "  ${CYAN}update-tools${RESET}                                         Git-pull all ~/tools"
print ""
print -P "  ${YELLOW}Reload your shell:  source ~/.zshrc${RESET}"
print ""
