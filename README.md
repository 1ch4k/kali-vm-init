# kali-vm-init

A single script to configure a fresh Kali Linux VM with a consistent, repeatable pentest environment.  
Written for **zsh**, the default shell on modern Kali.

---

## What it sets up

| Component | Description |
|-----------|-------------|
| System update | `apt update`, `apt full-upgrade`, `apt autoremove` |
| Python venv | `~/.venvs/pentest` with common pentest libraries |
| GVM / OpenVAS | Full Greenbone stack + `gvm-connect` socket helper |
| Vulnscan | Cloned and symlinked into Nmap's script directory |
| CopyQ | GUI clipboard history — open with `Win+V` |

---

## Usage

```zsh
git clone https://github.com/1ch4k/kali-vm-init.git
cd kali-vm-init
chmod +x kali-setup.sh
./kali-setup.sh
source ~/.zshrc
```

One-liner on a fresh machine:

```zsh
bash <(curl -fsSL https://raw.githubusercontent.com/1ch4k/kali-vm-init/main/kali-setup.sh)
```

---

## Clipboard — CopyQ

| Action | Shortcut |
|--------|----------|
| Copy | `Ctrl+C` |
| Paste | `Ctrl+V` |
| Open clipboard history | `Win+V` |

The `Win+V` shortcut is registered automatically via XFCE keyboard shortcuts on install.  
To change it: Settings → Keyboard → Application Shortcuts → find `copyq toggle`.

---

## Vulnscan

```zsh
sudo nmap -sV --script=vulscan/vulscan.nse <target>
sudo nmap -sV --script=vulscan/vulscan.nse --script-args vulscandb=exploitdb.csv <target>
```

---

## Python venv

```zsh
source ~/.venvs/pentest/bin/activate
deactivate
```

Libraries: `requests`, `paramiko`, `impacket`, `python-nmap`, `scapy`, `colorama`, `pwntools`, `gvm-tools`.

---

## GVM / OpenVAS

```zsh
sudo gvm-start
gvm-connect   # alias: gvmc
```

---

## Requirements

- Kali Linux
- Non-root user with sudo access
- XFCE desktop (default on Kali)
- Internet access

---

## Notes

Idempotent — safe to run multiple times. The system update always runs. Everything else is skipped if already present.
