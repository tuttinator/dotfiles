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

echo "Installed ac, irblaster and acsnap in $BIN"
