# kali-vm-init

A single script to configure a fresh Kali Linux VM with a consistent, repeatable pentest environment.

---

## What it sets up

| Component | Description |
|-----------|-------------|
| Python venv | Isolated environment at `~/.venvs/pentest` with common pentest libraries pre-installed |
| GVM / OpenVAS | Full Greenbone stack with a `gvm-connect` helper to interface with the local socket |
| Vulnscan | Clones `scipag/vulscan` and symlinks it into Nmap's script directory for direct use in `nmap` commands |
| CopyQ | GUI clipboard manager — records every `Ctrl+C`, press `Ctrl+V` to browse history and paste any previous item |

---

## Usage

```bash
git clone https://github.com/1ch4k/kali-vm-init.git
cd kali-vm-init
chmod +x kali-setup.sh
./kali-setup.sh
source ~/.bashrc
```

One-liner on a fresh machine:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/1ch4k/kali-vm-init/main/kali-setup.sh)
```

---

## Clipboard history

CopyQ runs silently in the background and records everything you copy.

| Action | Shortcut |
|--------|----------|
| Copy | `Ctrl+C` — as normal |
| Open history picker | `Ctrl+V` — opens GUI window with all copied items |
| Paste an item | Click it, or use arrow keys and `Enter` |
| Terminal paste | `Ctrl+Shift+V` — unchanged |

Starts automatically at login. Up to 200 items stored.  
To change the shortcut: CopyQ → File → Preferences → Global Shortcuts.

---

## Vulnscan in Nmap

Vulnscan is installed as an Nmap NSE script with no wrapper command. Use it directly:

```bash
# Standard scan
sudo nmap -sV --script=vulscan/vulscan.nse <target>

# Specific ports
sudo nmap -sV -p 80,443,8080 --script=vulscan/vulscan.nse <target>

# Target a specific CVE database
sudo nmap -sV --script=vulscan/vulscan.nse --script-args vulscandb=exploitdb.csv <target>
```

Available databases inside `~/tools/vulnscan/`: `exploitdb.csv`, `osvdb.csv`, `securitytracker.csv`, `xforce.csv`, `scipvuldb.csv`, `openvas.csv`.

---

## Python venv

```bash
# Activate
source ~/.venvs/pentest/bin/activate

# Deactivate
deactivate
```

Libraries included: `requests`, `paramiko`, `impacket`, `python-nmap`, `scapy`, `colorama`, `pwntools`, `gvm-tools`.

---

## GVM / OpenVAS

```bash
# Start services
sudo gvm-start

# Connect via socket
gvm-connect        # alias: gvmc
```

---

## Directory layout

```
$HOME/
├── .local/bin/              <- gvm-connect
├── .venvs/
│   └── pentest/
├── .config/
│   ├── autostart/
│   │   └── copyq.desktop
│   └── copyq/
│       └── copyq.conf
└── tools/
    ├── gvm/
    │   └── gvm-connect.sh
    └── vulnscan/

/usr/share/nmap/scripts/
└── vulscan -> ~/tools/vulnscan
```

---

## Requirements

- Kali Linux rolling
- Desktop environment for CopyQ GUI (XFCE, GNOME, etc.)
- Internet access for `apt` and `git`

---

## Notes

The script is idempotent. Running it multiple times is safe — existing repos are updated with `git pull`, existing venvs and symlinks are left untouched, and aliases are only written once.

