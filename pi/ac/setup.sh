#!/bin/bash
# Set up the IR blaster and webcam tools on a Pi:
#   - a venv with pyusb and Pillow under ~/.local/share/pi-ac
#   - `ac`, `irblaster` and `acsnap` wrappers in ~/.local/bin
#   - the udev rule that lets plugdev users open the IR blaster (asks for sudo)
# Safe to re-run.

set -euo pipefail

AC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/pi-ac"
VENV="$DATA_DIR/venv"
BIN="$HOME/.local/bin"

if ! command -v v4l2-ctl &>/dev/null; then
    sudo apt-get install -y v4l-utils
fi

mkdir -p "$DATA_DIR" "$BIN"
[[ -x "$VENV/bin/python" ]] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q -r "$AC_DIR/requirements.txt"

for pair in ac:ac.py irblaster:irblaster.py acsnap:snap.py; do
    name=${pair%%:*}
    script=${pair#*:}
    printf '#!/bin/sh\nexec "%s" "%s" "$@"\n' "$VENV/bin/python" "$AC_DIR/$script" >"$BIN/$name"
    chmod +x "$BIN/$name"
done

RULE=/etc/udev/rules.d/70-irblaster.rules
if ! cmp -s "$AC_DIR/70-irblaster.rules" "$RULE"; then
    sudo cp "$AC_DIR/70-irblaster.rules" "$RULE"
    sudo udevadm control --reload
    sudo udevadm trigger --attr-match=idVendor=045c
fi

# acd: the HTTP API for the phone app, as a user service that starts at boot.
# The OpenAI key, if any, goes in ~/.config/pi-ac/openai.env (mode 600):
#   OPENAI_API_KEY=...
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"
cat >"$UNIT_DIR/acd.service" <<EOF
[Unit]
Description=A/C control API (acd)
After=network-online.target

[Service]
ExecStart=$VENV/bin/python $AC_DIR/acd.py
EnvironmentFile=-%h/.config/pi-ac/openai.env
Restart=on-failure

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable acd.service
systemctl --user restart acd.service

if [[ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != yes ]]; then
    sudo loginctl enable-linger "$USER" # start user services at boot, not at login
fi

if ! tailscale serve status 2>/dev/null | grep -q 127.0.0.1:8765; then
    sudo tailscale serve --bg --http=80 127.0.0.1:8765
fi

echo "Installed ac, irblaster and acsnap in $BIN; acd is on http://$(hostname)/ over Tailscale"
