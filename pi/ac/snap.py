#!/usr/bin/env python3
"""acsnap [OUT.jpg | -] — grab one webcam frame as a standard JPEG.

UVC webcams stream MJPEG frames without Huffman tables, which strict decoders
(macOS Preview) reject, so the last of a short burst (auto-exposure needs a
few frames to settle) is decoded and re-saved. "-" writes to stdout:
  ssh <pi> acsnap - | chafa -
"""

import io
import os
import subprocess
import sys
import tempfile

from PIL import Image

DEVICE = os.environ.get("ACSNAP_DEVICE", "/dev/video0")
WARMUP_FRAMES = 15


def capture(width: int = 1280, height: int = 720) -> bytes:
    with tempfile.NamedTemporaryFile(suffix=".mjpg") as raw:
        subprocess.run(
            ["v4l2-ctl", "-d", DEVICE,
             f"--set-fmt-video=width={width},height={height},pixelformat=MJPG",
             "--stream-mmap", f"--stream-count={WARMUP_FRAMES}", f"--stream-to={raw.name}"],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        data = open(raw.name, "rb").read()
    start = data.rfind(b"\xff\xd8\xff")
    if start < 0:
        sys.exit("no JPEG frame captured")
    return data[start:]


def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else "snap.jpg"
    img = Image.open(io.BytesIO(capture())).convert("RGB")
    img.save(sys.stdout.buffer if out == "-" else out, "JPEG", quality=88)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
