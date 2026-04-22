#!/bin/bash

###############################################################################
# Headless Raspberry Pi SD-card provisioner (macOS).
#
# Reads the [pi] section of dotfiles.local.toml and writes:
#   - custom.toml   : stock Pi OS Bookworm first-boot config (user, Wi-Fi, SSH,
#                     hostname, locale, timezone). Handled by the firstboot
#                     service — no custom scripting required for the basics.
#   - firstrun.sh   : runs once on first boot after firstboot completes; installs
#                     Tailscale, joins the tailnet with the configured authkey,
#                     clones dotfiles, and runs bootstrap-linux.sh.
#   - cmdline.txt   : patched to invoke firstrun.sh on first boot.
#
# Default mode (safe): waits for an already-flashed SD card to mount as
#   /Volumes/bootfs and drops config files onto it.
#
# Optional --flash mode (destructive): uses rpi-imager --cli to download and
#   write Raspberry Pi OS Lite to a disk you specify. Will refuse to write to
#   the system disk; still requires you to confirm the target.
#
# Usage:
#   ./bootstrap-pi-sd.sh <hostname-suffix>
#   ./bootstrap-pi-sd.sh <hostname-suffix> --flash /dev/diskN
#
# Example:
#   ./bootstrap-pi-sd.sh kitchen                 # prepare-only
#   ./bootstrap-pi-sd.sh kitchen --flash /dev/disk6
###############################################################################

set -euo pipefail

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$DOTFILES_DIR/lib/common.sh"

CONFIG_FILE="$DOTFILES_DIR/dotfiles.local.toml"
BOOT_MOUNT="/Volumes/bootfs"
DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/calebtutty/dotfiles.git}"

###############################################################################
# Usage
###############################################################################
usage() {
    cat <<EOF
Usage: $(basename "$0") <hostname-suffix> [--flash /dev/diskN]

Arguments:
  hostname-suffix     Appended to [pi].hostname_prefix, e.g. "kitchen" -> "pi-kitchen"

Options:
  --flash /dev/diskN  Also flash Raspberry Pi OS Lite (64-bit) to the given
                      raw disk device before writing config. Destructive —
                      use with care. Without this flag the script only drops
                      config onto an already-flashed card mounted at
                      $BOOT_MOUNT.

Prerequisites:
  - $CONFIG_FILE with a populated [pi] section (see dotfiles.local.toml.example)
  - openssl in PATH (password hashing)
  - python3 in PATH (TOML parsing)
  - For --flash: Raspberry Pi Imager installed (brew install --cask raspberry-pi-imager)
EOF
}

if [[ $# -lt 1 ]]; then usage; exit 1; fi
if [[ "$1" == "-h" || "$1" == "--help" ]]; then usage; exit 0; fi

HOSTNAME_SUFFIX="$1"; shift
FLASH_TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --flash)
            FLASH_TARGET="${2:-}"
            if [[ -z "$FLASH_TARGET" ]]; then
                log_error "--flash requires a disk device argument"
                exit 1
            fi
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

###############################################################################
# Read [pi] config from dotfiles.local.toml
###############################################################################
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "$CONFIG_FILE not found."
    log_error "Copy dotfiles.local.toml.example to dotfiles.local.toml and fill the [pi] section."
    exit 1
fi

log_info "Reading [pi] section from $CONFIG_FILE..."

read_pi_config() {
    python3 - "$CONFIG_FILE" <<'PY'
import sys, tomllib, pathlib, json
cfg_path = pathlib.Path(sys.argv[1])
with cfg_path.open("rb") as f:
    cfg = tomllib.load(f)
pi = cfg.get("pi")
if not pi:
    sys.stderr.write("error: [pi] section missing in dotfiles.local.toml\n")
    sys.exit(1)
ts = pi.get("tailscale", {}) or {}
required = ["hostname_prefix", "username", "password", "wifi_ssid", "wifi_psk", "wifi_country"]
missing = [k for k in required if not pi.get(k)]
if missing:
    sys.stderr.write(f"error: missing required [pi] keys: {', '.join(missing)}\n")
    sys.exit(1)
out = {
    "hostname_prefix": pi["hostname_prefix"],
    "username":        pi["username"],
    "password":        pi["password"],
    "wifi_ssid":       pi["wifi_ssid"],
    "wifi_psk":        pi["wifi_psk"],
    "wifi_country":    pi["wifi_country"],
    "timezone":        pi.get("timezone", "Etc/UTC"),
    "locale":          pi.get("locale", "en_US.UTF-8"),
    "ts_authkey":      ts.get("authkey", ""),
    "ts_tags":         ",".join(ts.get("tags") or []),
    "ts_ssh":          bool(ts.get("ssh", False)),
}
print(json.dumps(out))
PY
}

PI_JSON="$(read_pi_config)"
HOSTNAME_PREFIX=$(echo "$PI_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["hostname_prefix"])')
PI_USER=$(        echo "$PI_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["username"])')
PI_PASSWORD=$(    echo "$PI_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["password"])')
WIFI_SSID=$(      echo "$PI_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["wifi_ssid"])')
WIFI_PSK=$(       echo "$PI_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["wifi_psk"])')
WIFI_COUNTRY=$(   echo "$PI_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["wifi_country"])')
TIMEZONE=$(       echo "$PI_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["timezone"])')
LOCALE=$(         echo "$PI_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["locale"])')
TS_AUTHKEY=$(     echo "$PI_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["ts_authkey"])')
TS_TAGS=$(        echo "$PI_JSON" | python3 -c 'import sys,json;print(json.load(sys.stdin)["ts_tags"])')
TS_SSH=$(         echo "$PI_JSON" | python3 -c 'import sys,json;print("true" if json.load(sys.stdin)["ts_ssh"] else "false")')

HOSTNAME="${HOSTNAME_PREFIX}-${HOSTNAME_SUFFIX}"
log_success "Config loaded. Target hostname: $HOSTNAME"

if [[ -z "$TS_AUTHKEY" || "$TS_AUTHKEY" == "tskey-auth-xxxxxxxxxxxx" ]]; then
    log_warning "No Tailscale authkey set; Pi will boot but won't join the tailnet automatically."
fi

###############################################################################
# Optional: flash the SD card with rpi-imager --cli
###############################################################################
if [[ -n "$FLASH_TARGET" ]]; then
    RPI_IMAGER="/Applications/Raspberry Pi Imager.app/Contents/MacOS/rpi-imager"
    if [[ ! -x "$RPI_IMAGER" ]]; then
        log_error "Raspberry Pi Imager not found at $RPI_IMAGER"
        log_error "Install with: brew install --cask raspberry-pi-imager"
        exit 1
    fi

    # Guard against the system disk. On Apple Silicon the system is disk3/disk4
    # (synthesized); on Intel it's disk1. Either way, refuse anything under disk3.
    if [[ ! "$FLASH_TARGET" =~ ^/dev/disk[4-9][0-9]*$ && ! "$FLASH_TARGET" =~ ^/dev/disk[1-9][0-9]+$ ]]; then
        log_error "Refusing to flash $FLASH_TARGET — looks like a system or low-numbered disk."
        log_error "Run 'diskutil list external physical' to find the SD card."
        exit 1
    fi

    log_warning "About to ERASE and flash Raspberry Pi OS Lite to: $FLASH_TARGET"
    diskutil list "$FLASH_TARGET" || { log_error "diskutil can't see $FLASH_TARGET"; exit 1; }
    read -rp "Type the device path again to confirm ($FLASH_TARGET): " CONFIRM
    if [[ "$CONFIRM" != "$FLASH_TARGET" ]]; then
        log_error "Confirmation mismatch, aborting."
        exit 1
    fi

    log_info "Unmounting $FLASH_TARGET..."
    diskutil unmountDisk "$FLASH_TARGET" || true

    # Pi OS Lite 64-bit (Bookworm). URL is stable and served by the Pi foundation.
    IMG_URL="https://downloads.raspberrypi.com/raspios_lite_arm64_latest"
    log_info "Flashing with rpi-imager --cli (this can take several minutes)..."
    "$RPI_IMAGER" --cli "$IMG_URL" "$FLASH_TARGET"
    log_success "Flash complete"

    # The boot partition auto-mounts after flashing; give it a moment.
    log_info "Waiting for $BOOT_MOUNT to mount..."
    for _ in {1..30}; do
        [[ -d "$BOOT_MOUNT" ]] && break
        sleep 1
    done
fi

###############################################################################
# Verify boot partition is mounted
###############################################################################
if [[ ! -d "$BOOT_MOUNT" ]]; then
    log_error "$BOOT_MOUNT is not mounted."
    log_error "Insert a freshly flashed Pi OS SD card and wait for it to appear in Finder,"
    log_error "or re-run with --flash /dev/diskN to flash one now."
    exit 1
fi
log_success "Boot partition found at $BOOT_MOUNT"

###############################################################################
# Hash the password (openssl SHA-512 crypt)
###############################################################################
log_info "Hashing user password..."
PI_PASSWORD_HASH=$(openssl passwd -6 "$PI_PASSWORD")

###############################################################################
# Write custom.toml (stock Pi OS first-boot config)
#
# Schema: https://www.raspberrypi.com/documentation/computers/configuration.html#configuration-on-first-boot
###############################################################################
log_info "Writing $BOOT_MOUNT/custom.toml..."
cat > "$BOOT_MOUNT/custom.toml" <<EOF
# Raspberry Pi OS first-boot config. Generated by bootstrap-pi-sd.sh.
config_version = 1

[system]
hostname = "$HOSTNAME"

[user]
name = "$PI_USER"
password = "$PI_PASSWORD_HASH"
password_encrypted = true

[ssh]
enabled = true
password_authentication = true

[wlan]
ssid = "$WIFI_SSID"
password = "$WIFI_PSK"
password_encrypted = false
hidden = false
country = "$WIFI_COUNTRY"

[locale]
keymap   = "us"
timezone = "$TIMEZONE"
EOF

###############################################################################
# Write firstrun.sh — runs once after firstboot completes
###############################################################################
log_info "Writing $BOOT_MOUNT/firstrun.sh..."
# Build tailscale up flags
TS_UP_FLAGS="--authkey=$TS_AUTHKEY --hostname=$HOSTNAME"
[[ "$TS_SSH" == "true" ]] && TS_UP_FLAGS="$TS_UP_FLAGS --ssh"
[[ -n "$TS_TAGS"      ]] && TS_UP_FLAGS="$TS_UP_FLAGS --advertise-tags=$TS_TAGS"

cat > "$BOOT_MOUNT/firstrun.sh" <<EOF
#!/bin/bash
# Runs once on first boot. Log to /boot/firmware/firstrun.log so you can inspect
# it over SSH or by pulling the card afterwards.
set -eux
exec > /boot/firmware/firstrun.log 2>&1

# Wait for network (up to 2 minutes)
for i in \$(seq 1 60); do
    if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then break; fi
    sleep 2
done

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates git

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Join the tailnet (no-op if authkey is empty — 'tailscale up' will just fail loud)
if [ -n "$TS_AUTHKEY" ]; then
    tailscale up $TS_UP_FLAGS
fi

# Clone dotfiles into the Pi user's home and run bootstrap-linux.sh as that user
sudo -u "$PI_USER" git clone --depth=1 "$DOTFILES_REPO_URL" "/home/$PI_USER/dotfiles" || true
if [ -x "/home/$PI_USER/dotfiles/bootstrap-linux.sh" ]; then
    sudo -u "$PI_USER" bash -lc "cd /home/$PI_USER/dotfiles && ./bootstrap-linux.sh" || true
fi

# Self-disable: remove the cmdline.txt hook so we don't run again
sed -i 's| systemd.run.*||' /boot/firmware/cmdline.txt || true
rm -f /boot/firmware/firstrun.sh
EOF
chmod +x "$BOOT_MOUNT/firstrun.sh"

###############################################################################
# Patch cmdline.txt to invoke firstrun.sh once
###############################################################################
CMDLINE="$BOOT_MOUNT/cmdline.txt"
if [[ -f "$CMDLINE" ]]; then
    log_info "Patching cmdline.txt to run firstrun.sh on first boot..."
    # Strip any previous systemd.run hooks, then append ours. cmdline.txt must
    # stay on a single line.
    CURRENT=$(tr -d '\n' < "$CMDLINE")
    CURRENT=$(echo "$CURRENT" | sed -E 's| systemd\.run=[^ ]+||g; s| systemd\.run_success_action=[^ ]+||g; s| systemd\.unit=[^ ]+||g')
    HOOK=' systemd.run=/boot/firmware/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target'
    echo "${CURRENT}${HOOK}" > "$CMDLINE"
else
    log_warning "cmdline.txt not found at $CMDLINE — firstrun.sh won't auto-execute."
fi

###############################################################################
# Flush + unmount
###############################################################################
log_info "Syncing and ejecting..."
sync
diskutil eject "$BOOT_MOUNT" || log_warning "Couldn't auto-eject; you can pull the card manually."

log_success "Done. Insert the SD into the Pi and power it on."
echo ""
echo "Expected timeline:"
echo "  ~1 min  : firstboot creates user, connects Wi-Fi, enables SSH, reboots"
echo "  ~3 min  : firstrun.sh installs Tailscale and joins the tailnet"
echo "  ~5-15 min: bootstrap-linux.sh finishes (Node, zsh plugins, etc.)"
echo ""
echo "Once joined, find the Pi on your tailnet:"
echo "  tailscale status | grep $HOSTNAME"
echo "  ssh $PI_USER@$HOSTNAME"
echo ""
echo "If it doesn't show up after ~5 min, boot with a monitor and inspect:"
echo "  sudo cat /boot/firmware/firstrun.log"
