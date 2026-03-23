#!/usr/bin/env bash
# =============================================================================
#  kali-setup.sh — Fresh Kali VM bootstrapper
#  Installs: Python venv · GVM tools · Vulnscan (nmap scripts) · CopyQ
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${GREEN}[+]${RESET} $*"; }
info()    { echo -e "${CYAN}[i]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
section() {
    echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  $*${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════${RESET}"
}

# ── Paths ─────────────────────────────────────────────────────────────────────
TOOLS_DIR="$HOME/tools"
VENV_DIR="$HOME/.venvs/pentest"
VULNSCAN_DIR="$TOOLS_DIR/vulnscan"
GVM_DIR="$TOOLS_DIR/gvm"
BIN_DIR="$HOME/.local/bin"

# ── Ensure local bin is in PATH ───────────────────────────────────────────────
mkdir -p "$BIN_DIR"
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$BIN_DIR:$PATH"
fi

# =============================================================================
section "1 · System update & base dependencies"
# =============================================================================
log "Updating package lists..."
sudo apt-get update -qq

log "Installing base packages..."
sudo apt-get install -y -qq \
    python3 python3-pip python3-venv python3-dev \
    git curl wget unzip build-essential \
    libssl-dev libffi-dev \
    nmap \
    2>/dev/null

log "Base packages installed."

# =============================================================================
section "2 · Python virtual environment"
# =============================================================================
mkdir -p "$(dirname "$VENV_DIR")"

if [ -d "$VENV_DIR" ]; then
    warn "Venv already exists at $VENV_DIR — skipping creation."
else
    log "Creating Python venv at $VENV_DIR ..."
    python3 -m venv "$VENV_DIR"
    log "Venv created."
fi

# Activate for the rest of this script
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

log "Upgrading pip inside venv..."
pip install --upgrade pip setuptools wheel -q

log "Installing common pentest Python libraries..."
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
section "3 · GVM / OpenVAS tools"
# =============================================================================
mkdir -p "$GVM_DIR"

log "Checking for system GVM daemon (gvmd)..."
if command -v gvmd &>/dev/null; then
    info "gvmd found: $(gvmd --version 2>/dev/null | head -1)"
else
    warn "gvmd not found. Installing Greenbone OpenVAS stack..."
    sudo apt-get install -y -qq \
        gvm openvas gvmd gsa gsad \
        2>/dev/null || warn "Some GVM packages may not be available — check your Kali repo."

    log "Running gvm-setup (this can take several minutes)..."
    if command -v gvm-setup &>/dev/null; then
        sudo gvm-setup 2>&1 | tee "$GVM_DIR/setup.log" \
            || warn "gvm-setup finished with warnings — check $GVM_DIR/setup.log"
    fi
fi

# GVM quick-connect helper
cat > "$GVM_DIR/gvm-connect.sh" << 'EOF'
#!/usr/bin/env bash
GVM_SOCKET="/run/gvmd/gvmd.sock"
if [ ! -S "$GVM_SOCKET" ]; then
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
section "4 · Vulnscan — install for use in Nmap commands"
# =============================================================================
#
#  Vulnscan is installed as an Nmap NSE script only.
#  No wrapper command is created — use it directly in your nmap calls:
#
#    sudo nmap -sV --script=vulscan/vulscan.nse <target>
#
if [ -d "$VULNSCAN_DIR/.git" ]; then
    warn "Vulnscan already cloned — pulling latest..."
    git -C "$VULNSCAN_DIR" pull --ff-only
else
    log "Cloning Vulnscan into $VULNSCAN_DIR ..."
    git clone --depth=1 https://github.com/scipag/vulscan.git "$VULNSCAN_DIR"
fi

NMAP_SCRIPTS_DIR="/usr/share/nmap/scripts"
VULSCAN_LINK="$NMAP_SCRIPTS_DIR/vulscan"

if [ -L "$VULSCAN_LINK" ]; then
    info "Vulscan symlink already exists at $VULSCAN_LINK"
elif [ -d "$VULSCAN_LINK" ]; then
    warn "Vulscan directory already at $NMAP_SCRIPTS_DIR — skipping symlink."
else
    log "Creating symlink: $VULSCAN_LINK → $VULNSCAN_DIR"
    sudo ln -s "$VULNSCAN_DIR" "$VULSCAN_LINK"
fi

log "Updating Nmap script database..."
sudo nmap --script-updatedb -q 2>/dev/null || warn "nmap --script-updatedb failed (non-fatal)"

info "Vulnscan ready. Use it in nmap:"
info "  sudo nmap -sV --script=vulscan/vulscan.nse <target>"

# =============================================================================
section "5 · CopyQ — GUI clipboard manager (Ctrl+V opens history)"
# =============================================================================
#
#  CopyQ records every Ctrl+C into a persistent history list.
#  Press Ctrl+V to pop open the GUI picker and click any previous
#  item to paste it — exactly like Win+V on Windows.
#
#  NOTE: Ctrl+V is remapped as the CopyQ global toggle. Inside terminals
#  the standard terminal paste shortcut is Ctrl+Shift+V (unchanged).
#
log "Installing CopyQ..."
if ! command -v copyq &>/dev/null; then
    sudo apt-get install -y -qq copyq 2>/dev/null \
        || { warn "CopyQ not in apt — trying flatpak...";
             sudo apt-get install -y -qq flatpak 2>/dev/null;
             sudo flatpak remote-add --if-not-exists flathub \
                 https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null;
             sudo flatpak install -y flathub com.github.hluk.copyq 2>/dev/null \
                 || warn "Could not auto-install CopyQ. Run manually: sudo apt install copyq"; }
else
    info "CopyQ already installed."
fi

if command -v copyq &>/dev/null; then
    log "CopyQ installed: $(copyq --version 2>/dev/null | head -1)"

    # ── Autostart on every login ──────────────────────────────────────────────
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

    # ── Global shortcut: Ctrl+V → open clipboard history GUI ─────────────────
    COPYQ_CFG_DIR="$HOME/.config/copyq"
    mkdir -p "$COPYQ_CFG_DIR"
    COPYQ_CFG="$COPYQ_CFG_DIR/copyq.conf"

    if [ ! -f "$COPYQ_CFG" ] || ! grep -q "toggle" "$COPYQ_CFG" 2>/dev/null; then
        cat > "$COPYQ_CFG" << 'EOF'
[General]
autostart=true
maxitems=200
savedelay=5000

[GlobalShortcuts]
toggle=ctrl+v
EOF
        log "Global shortcut configured: Ctrl+V → open CopyQ history"
    else
        info "CopyQ config already exists — shortcut not overwritten."
        info "To change it: CopyQ → File → Preferences → Global Shortcuts"
    fi

    # Start CopyQ now without waiting for a reboot
    if ! pgrep -x copyq &>/dev/null; then
        copyq &
        disown
        log "CopyQ started in background."
    else
        info "CopyQ is already running."
    fi

    echo ""
    echo -e "  ${BOLD}┌─ How to use CopyQ ─────────────────────────────────────────┐${RESET}"
    echo -e "  ${BOLD}│${RESET}  1. Copy anything normally with  ${CYAN}Ctrl+C${RESET}                  ${BOLD}│${RESET}"
    echo -e "  ${BOLD}│${RESET}  2. Press  ${CYAN}Ctrl+V${RESET}  to open the clipboard history window  ${BOLD}│${RESET}"
    echo -e "  ${BOLD}│${RESET}  3. Click (or arrow + Enter) any item to paste it        ${BOLD}│${RESET}"
    echo -e "  ${BOLD}│${RESET}  4. Stores up to 200 items · starts at every login       ${BOLD}│${RESET}"
    echo -e "  ${BOLD}│${RESET}  ${YELLOW}Note:${RESET} terminal paste stays on  ${CYAN}Ctrl+Shift+V${RESET}             ${BOLD}│${RESET}"
    echo -e "  ${BOLD}└────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
else
    warn "CopyQ installation could not be completed."
    warn "Install it manually:  sudo apt install copyq"
fi

# =============================================================================
section "6 · Shell aliases"
# =============================================================================
if ! grep -q "# kali-setup aliases" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << EOF

# ── kali-setup aliases ────────────────────────────────────────────────────────
alias gvmc='gvm-connect'
alias update-tools='cd $TOOLS_DIR && for d in */; do [ -d "\$d/.git" ] && echo "→ \$d" && git -C "\$d" pull --ff-only; done'
EOF
    log "Aliases added to .bashrc"
fi

# =============================================================================
section "✅  Setup complete!"
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}  Everything is installed. Quick reference:${RESET}"
echo ""
echo -e "  ${CYAN}source ~/.venvs/pentest/bin/activate${RESET}                Activate Python venv"
echo -e "  ${CYAN}Ctrl+C  →  Ctrl+V${RESET}                                  Open CopyQ history GUI"
echo -e "  ${CYAN}sudo nmap -sV --script=vulscan/vulscan.nse <host>${RESET}   Run Vulscan"
echo -e "  ${CYAN}gvm-connect  (alias: gvmc)${RESET}                         Connect to GVM socket"
echo -e "  ${CYAN}update-tools${RESET}                                        Git-pull all ~/tools"
echo ""
echo -e "  ${YELLOW}Reload your shell:  source ~/.bashrc${RESET}"
echo ""
