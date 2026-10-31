#!/usr/bin/env python3
"""ac — switch a Coolix (Midea) air conditioner and confirm it with the webcam.

  ac on | off | cool NN    send the command, then watch the camera until the
                           unit is in the expected state (one resend if not)
  ac status                on / off / unknown, from the camera alone
  ac calibrate             switch the unit off then on, find the part of the
                           frame that changes (flap, display) and store
                           reference crops of both states

Exit status: 0 confirmed, 1 not confirmed, 2 sent but unverifiable (no
calibration). Calibration lives in ~/.local/share/pi-ac/, outside the repo.
"""

from __future__ import annotations

import contextlib
import fcntl
import io
import json
import os
import sys
import time
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import irblaster
import snap

DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "pi-ac"
CONFIG = DATA / "ac.json"
FEATURE = (48, 24)        # ROI is compared at this size
CELL = 8                  # diff grid cell, in pixels of the 1280x720 frame
POLL = (6, 10, 15, 20)    # seconds after sending to check the camera
MARGIN = 0.1              # how much better one reference must match


# --- camera features ---------------------------------------------------------


def pixels(img: Image.Image) -> list[int]:
    """Pixel values (getdata is deprecated from Pillow 12)."""
    return list(getattr(img, "get_flattened_data", img.getdata)())


def frame() -> Image.Image:
    return Image.open(io.BytesIO(snap.capture())).convert("L")


def feature(img: Image.Image, roi: list[int]) -> list[float]:
    """ROI as a small, zero-mean, unit-variance vector: exposure changes cancel out."""
    px = pixels(img.crop(roi).resize(FEATURE, Image.BOX))
    mean = sum(px) / len(px)
    sd = (sum((p - mean) ** 2 for p in px) / len(px)) ** 0.5 or 1.0
    return [(p - mean) / sd for p in px]


def corr(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b)) / len(a)


def classify(img: Image.Image, cfg: dict) -> tuple[str, float, float]:
    f = feature(img, cfg["roi"])
    c_on, c_off = corr(f, cfg["on"]), corr(f, cfg["off"])
    if c_on - c_off > MARGIN:
        return "on", c_on, c_off
    if c_off - c_on > MARGIN:
        return "off", c_on, c_off
    return "unknown", c_on, c_off


def load_config() -> dict | None:
    return json.loads(CONFIG.read_text()) if CONFIG.exists() else None


def status(cfg: dict) -> str:
    state, c_on, c_off = classify(frame(), cfg)
    print(f"camera: {state} (match on {c_on:.2f}, off {c_off:.2f})", file=sys.stderr)
    return state


# --- IR ------------------------------------------------------------------------


def send(code: int) -> None:
    dev, ep_in, ep_out = irblaster.open_device()
    try:
        irblaster.handshake(ep_in, ep_out)
        irblaster.transmit(ep_in, ep_out, irblaster.DEFAULT_FREQ, irblaster.coolix_timings(code))
    finally:
        irblaster.usb.util.dispose_resources(dev)


# --- calibration ------------------------------------------------------------------


def normalised(img: Image.Image) -> Image.Image:
    """Scale to a fixed mean brightness so auto-exposure doesn't count as change."""
    mean = sum(pixels(img)) / (img.width * img.height)
    return img.point(lambda p: min(255, int(p * 128 / max(mean, 1))))


def changed_region(off: list[Image.Image], on: list[Image.Image]) -> list[int]:
    """Bounding box of the strongest connected area that differs between states
    but not between two frames of the same state (so people moving are ignored)."""
    grid = (1280 // CELL, 720 // CELL)

    def cells(a, b):
        d = ImageChops.difference(normalised(a), normalised(b)).filter(ImageFilter.BoxBlur(2))
        return pixels(d.resize(grid, Image.BOX))

    state = cells(off[0], on[0])
    noise = [max(x, y) for x, y in zip(cells(off[0], off[1]), cells(on[0], on[1]))]
    score = [max(0, s - 2 * n) for s, n in zip(state, noise)]
    peak = max(score)
    if peak < 12:
        raise RuntimeError("the unit looks the same on and off; is it in view?")
    hot = {i for i, s in enumerate(score) if s >= peak * 0.35}

    best, best_total = None, 0
    seen: set[int] = set()
    w = grid[0]
    for start in hot:
        if start in seen:
            continue
        comp, stack = [], [start]
        seen.add(start)
        while stack:
            i = stack.pop()
            comp.append(i)
            x, y = i % w, i // w
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    j = (y + dy) * w + (x + dx)
                    if 0 <= x + dx < w and j in hot and j not in seen:
                        seen.add(j)
                        stack.append(j)
        total = sum(score[i] for i in comp)
        if total > best_total:
            best, best_total = comp, total

    xs = [i % w for i in best]
    ys = [i // w for i in best]
    pad = 3
    return [max(0, (min(xs) - pad) * CELL), max(0, (min(ys) - pad) * CELL),
            min(1280, (max(xs) + 1 + pad) * CELL), min(720, (max(ys) + 1 + pad) * CELL)]


def calibrate() -> int:
    print("switching off...", file=sys.stderr)
    send(irblaster.COOLIX["off"])
    time.sleep(15)
    off = [frame(), (time.sleep(1), frame())[1]]
    print("switching on...", file=sys.stderr)
    send(irblaster.COOLIX["on"])
    time.sleep(15)
    on = [frame(), (time.sleep(1), frame())[1]]

    roi = changed_region(off, on)
    cfg = {"roi": roi, "on": feature(on[0], roi), "off": feature(off[0], roi)}
    DATA.mkdir(parents=True, exist_ok=True)
    CONFIG.write_text(json.dumps(cfg))

    preview = Image.merge("RGB", [on[0]] * 3)
    ImageDraw.Draw(preview).rectangle(roi, outline=(255, 0, 0), width=3)
    preview.save(DATA / "calibration.jpg", quality=85)
    checks = [classify(img, cfg)[0] for img in (off[1], on[1])]
    print(f"region {roi}; second frames read as {checks[0]}/{checks[1]} (want off/on)")
    print(f"preview: {DATA / 'calibration.jpg'}")
    return 0 if checks == ["off", "on"] else 1


# --- commands ----------------------------------------------------------------------


@contextlib.contextmanager
def device_lock():
    """One user of the IR blaster and camera at a time (CLI and acd share it)."""
    DATA.mkdir(parents=True, exist_ok=True)
    with open(DATA / "lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def command(action: str, temp: int | None = None) -> tuple[str, int, str]:
    """Resolve an action to (code, expected state, label)."""
    if action == "on":
        return irblaster.COOLIX["on"], "on", "on (cool 17 °C)"
    if action == "off":
        return irblaster.COOLIX["off"], "off", "off"
    if action == "cool" and temp in irblaster.COOLIX_TEMP:
        return irblaster.coolix_cool(temp), "on", f"cooling at {temp} °C"
    raise ValueError("action must be on, off or cool with a temperature of 17-30")


def switch(code: int, want: str, label: str) -> tuple[int, str]:
    """Send, then watch the camera. Returns (exit status, message):
    0 confirmed, 1 not confirmed, 2 sent but uncalibrated."""
    cfg = load_config()
    send(code)
    if cfg is None:
        return 2, f"Sent {label}; not verified (run `ac calibrate`)"
    for attempt in (1, 2):
        start = time.monotonic()
        for t in POLL:
            time.sleep(max(0, t - (time.monotonic() - start)))
            if status(cfg) == want:
                return 0, f"A/C {label} ✓ confirmed by camera" + (" (after resend)" if attempt == 2 else "")
        if attempt == 1:
            print("no change seen; resending", file=sys.stderr)
            send(code)
    return 1, f"Sent {label} twice but the camera doesn't show it {want} ✗"


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    cmd = args[0]
    with device_lock():
        if cmd in ("on", "off", "cool"):
            temp = int(args[1]) if cmd == "cool" and len(args) == 2 and args[1].isdigit() else None
            try:
                rc, message = switch(*command(cmd, temp))
            except ValueError as e:
                sys.exit(str(e))
            print(message)
            return rc
        if cmd == "status":
            cfg = load_config()
            if cfg is None:
                sys.exit("not calibrated; run `ac calibrate`")
            state = status(cfg)
            print(f"A/C is {state}")
            return 0 if state != "unknown" else 1
        if cmd == "calibrate":
            return calibrate()
    sys.exit("usage: ac on | off | cool 17-30 | status | calibrate")


if __name__ == "__main__":
    raise SystemExit(main())
