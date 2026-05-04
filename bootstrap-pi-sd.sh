#!/bin/bash

###############################################################################
# Headless Raspberry Pi SD-card provisioner (macOS).
#
# Reads the [pi] section of dotfiles.local.toml and writes:
#   - custom.toml   : stock Pi OS Bookworm first-boot config (user, Wi-Fi, SSH,
#                     authorized keys, hostname, locale, timezone). Handled by
#                     the firstboot service — no custom scripting required for
#                     the basics.
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
  - at least one SSH public key in ~/.ssh/*.pub
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
# Collect local SSH public keys for passwordless SSH to the Pi
###############################################################################
SSH_AUTHORIZED_KEYS="$(mktemp)"
trap 'rm -f "$SSH_AUTHORIZED_KEYS"' EXIT

for key_file in "$HOME"/.ssh/*.pub; do
    [[ -f "$key_file" ]] || continue
    if grep -Eq '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com) ' "$key_file"; then
        cat "$key_file" >> "$SSH_AUTHORIZED_KEYS"
    else
        log_warning "Skipping unrecognized SSH public key: $key_file"
    fi
done

if [[ ! -s "$SSH_AUTHORIZED_KEYS" ]]; then
    log_error "No SSH public keys found in $HOME/.ssh/*.pub"
    log_error "Create one first, e.g. ssh-keygen -t ed25519 -C \"you@example.com\""
    exit 1
fi
KEY_COUNT=$(wc -l < "$SSH_AUTHORIZED_KEYS" | tr -d ' ')
log_success "Collected $KEY_COUNT SSH public key(s) for the Pi user's authorized_keys"

AUTHORIZED_KEYS_TOML=$(python3 - "$SSH_AUTHORIZED_KEYS" <<'PY'
import json
import pathlib
import sys

keys = [
    line.strip()
    for line in pathlib.Path(sys.argv[1]).read_text().splitlines()
    if line.strip()
]
print("authorized_keys = [")
for key in keys:
    print(f"  {json.dumps(key)},")
print("]")
PY
)

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

# Escape user-supplied strings safely for TOML/YAML output using JSON-style
# quoted strings (accepted by both formats).
json_quote() {
    python3 - "$1" <<'PY'
import json, sys
print(json.dumps(sys.argv[1]))
PY
}

HOSTNAME_Q=$(json_quote "$HOSTNAME")
PI_USER_Q=$(json_quote "$PI_USER")
PI_PASSWORD_HASH_Q=$(json_quote "$PI_PASSWORD_HASH")
WIFI_SSID_Q=$(json_quote "$WIFI_SSID")
WIFI_PSK_Q=$(json_quote "$WIFI_PSK")
WIFI_COUNTRY_Q=$(json_quote "$WIFI_COUNTRY")
TIMEZONE_Q=$(json_quote "$TIMEZONE")

AUTHORIZED_KEYS_YAML_INLINE=$(python3 - "$SSH_AUTHORIZED_KEYS" <<'PY'
import json
import pathlib
import sys

keys = [
    line.strip()
    for line in pathlib.Path(sys.argv[1]).read_text().splitlines()
    if line.strip()
]
print(json.dumps(keys))
PY
)

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
hostname = $HOSTNAME_Q

[user]
name = $PI_USER_Q
password = $PI_PASSWORD_HASH_Q
password_encrypted = true

[ssh]
enabled = true
password_authentication = true
$AUTHORIZED_KEYS_TOML

[wlan]
ssid = $WIFI_SSID_Q
password = $WIFI_PSK_Q
password_encrypted = false
hidden = false
country = $WIFI_COUNTRY_Q

[locale]
keymap   = "us"
timezone = $TIMEZONE_Q
EOF

###############################################################################
# Cloud-init compatibility (newer Raspberry Pi OS images ship user-data and
# network-config templates on bootfs)
###############################################################################
if [[ -f "$BOOT_MOUNT/user-data" || -f "$BOOT_MOUNT/network-config" ]]; then
        log_info "Writing cloud-init compatible user-data and network-config..."

        cat > "$BOOT_MOUNT/user-data" <<EOF
#cloud-config
hostname: $HOSTNAME_Q
users:
    - default
    - {name: $PI_USER_Q, gecos: $PI_USER_Q, groups: [adm, sudo, audio, video, plugdev, users], shell: "/bin/bash", lock_passwd: false, passwd: $PI_PASSWORD_HASH_Q, ssh_authorized_keys: $AUTHORIZED_KEYS_YAML_INLINE}
ssh_pwauth: true
disable_root: true
chpasswd: {expire: false}
EOF

        cat > "$BOOT_MOUNT/network-config" <<EOF
network:
    version: 2
    ethernets:
        eth0:
            dhcp4: true
            optional: true
    wifis:
        wlan0:
            dhcp4: true
            optional: true
            access-points:
                $WIFI_SSID_Q:
                    password: $WIFI_PSK_Q
            regulatory-domain: $WIFI_COUNTRY_Q
EOF
fi

###############################################################################
# Legacy compatibility (older Raspberry Pi OS images)
###############################################################################
log_info "Writing legacy compatibility files (userconf.txt, wpa_supplicant.conf, ssh)..."
printf '%s:%s\n' "$PI_USER" "$PI_PASSWORD_HASH" > "$BOOT_MOUNT/userconf.txt"
cat > "$BOOT_MOUNT/wpa_supplicant.conf" <<EOF
country=$WIFI_COUNTRY
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
        ssid=$WIFI_SSID_Q
        psk=$WIFI_PSK_Q
}
EOF
touch "$BOOT_MOUNT/ssh"

# Older versions staged this as a separate boot file. Key seeding now happens
# through custom.toml so firstboot owns user creation and permissions.
rm -f "$BOOT_MOUNT/authorized_keys"

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
set -uxo pipefail
FROM_CMDLINE=true
if [ "\${1:-}" = "--retry" ]; then
    FROM_CMDLINE=false
fi

exec >> /boot/firmware/firstrun.log 2>&1
echo ""
echo "===== \$(date -Is) firstrun.sh start (from_cmdline=\$FROM_CMDLINE) ====="

install_retry_service() {
    cat > /etc/systemd/system/pi-firstrun-retry.service <<'UNIT'
[Unit]
Description=Retry Pi first-run provisioning until successful
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/boot/firmware/firstrun.sh --retry

[Install]
WantedBy=multi-user.target
UNIT

    systemctl daemon-reload || true
    systemctl enable pi-firstrun-retry.service || true
}

disable_retry_service() {
    systemctl disable --now pi-firstrun-retry.service || true
    rm -f /etc/systemd/system/pi-firstrun-retry.service
    systemctl daemon-reload || true
}

ensure_hosts_matches_hostname() {
    local current_hostname
    current_hostname="\$(hostnamectl --static 2>/dev/null || hostname)"
    if grep -qE '^127\\.0\\.1\\.1[[:space:]]+' /etc/hosts; then
        sed -i -E "s|^127\\.0\\.1\\.1[[:space:]].*|127.0.1.1\\t\$current_hostname|" /etc/hosts || true
    else
        echo -e "127.0.1.1\\t\$current_hostname" >> /etc/hosts || true
    fi
}

cleanup() {
    # Always remove kernel-command-line hook so normal boot continues.
    # Retry logic is handled by pi-firstrun-retry.service.
    if [ "\$FROM_CMDLINE" = "true" ]; then
        sed -i 's| systemd.run.*||' /boot/firmware/cmdline.txt || true
    fi
}
trap cleanup EXIT

install_retry_service
ensure_hosts_matches_hostname

run_step() {
    local description="\$1"
    shift
    echo "==> \$description"
    if ! "\$@"; then
        echo "WARNING: failed: \$description"
        return 1
    fi
}

# Wait for network route + DNS (up to 10 minutes)
NETWORK_READY=false
for i in \$(seq 1 120); do
    if ip route get 1.1.1.1 >/dev/null 2>&1 && getent hosts deb.debian.org >/dev/null 2>&1; then
        NETWORK_READY=true
        break
    fi
    sleep 5
done

if [ "\$NETWORK_READY" != "true" ]; then
    echo "WARNING: network/DNS did not become ready; retry service will try again next boot."
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive
run_step "apt-get update" apt-get update || exit 0
run_step "install curl, ca-certificates, git" apt-get install -y curl ca-certificates git || exit 0

# Install Tailscale
echo "==> install Tailscale"
if ! curl -fsSL https://tailscale.com/install.sh | sh; then
    echo "WARNING: failed: install Tailscale"
    exit 0
fi

# Join the tailnet (no-op if authkey is empty — 'tailscale up' will just fail loud)
if [ -n "$TS_AUTHKEY" ]; then
    run_step "join Tailscale" tailscale up $TS_UP_FLAGS || exit 0
fi

# Clone dotfiles into the Pi user's home and run bootstrap-linux.sh as that user
sudo -u "$PI_USER" git clone --depth=1 "$DOTFILES_REPO_URL" "/home/$PI_USER/dotfiles" || true
if [ -x "/home/$PI_USER/dotfiles/bootstrap-linux.sh" ]; then
    sudo -u "$PI_USER" bash -lc "cd /home/$PI_USER/dotfiles && ./bootstrap-linux.sh" || true
fi

disable_retry_service
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
