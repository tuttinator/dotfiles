#!/usr/bin/env python3
"""acd — HTTP API for the ac tools, for a phone app on the tailnet.

Listens on 127.0.0.1 only; publish it to the tailnet with
  tailscale serve --bg --http=80 127.0.0.1:8765
Requests must arrive through `tailscale serve`, which sets the caller's
Tailscale-User-Login header (set ACD_ALLOWED_USERS to a comma-separated list
of logins to narrow it further).

  GET  /api/status      {"state": "on"|"off"|"unknown", ...} from the camera
  GET  /api/snapshot    JPEG of the area around the unit (?full=1: whole frame)
  POST /api/command     {"action": "on"|"off"|"cool", "temp": 17-30}
  POST /api/describe    OpenAI reads the unit's display from a crop of it;
                        needs OPENAI_API_KEY (and optional OPENAI_MODEL)

Only the crop around the unit is ever sent to OpenAI, never the full frame.
"""

from __future__ import annotations

import base64
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from PIL import Image

import ac
import snap

HOST, PORT = "127.0.0.1", int(os.environ.get("ACD_PORT", "8765"))
ALLOWED = {u.strip() for u in os.environ.get("ACD_ALLOWED_USERS", "").split(",") if u.strip()}
OPENAI_MODEL = os.environ.get("OPENAI_MODEL", "gpt-5-mini")

DESCRIBE_PROMPT = (
    "This is a webcam crop of a wall-mounted split-system air conditioner, seen "
    "from below at an angle. Report what you can actually see. power: 'on' if the "
    "display is lit or the louvre/flap is open, 'off' if the display is dark and "
    "the flap is closed, else 'unknown'. temperature: the number on the display in "
    "degrees C, or null if it isn't legible. mode: only if an icon or text shows it, "
    "else null. notes: one short sentence on anything relevant (e.g. why a value "
    "is uncertain)."
)
DESCRIBE_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["power", "temperature", "mode", "notes"],
    "properties": {
        "power": {"type": "string", "enum": ["on", "off", "unknown"]},
        "temperature": {"type": ["integer", "null"]},
        "mode": {"type": ["string", "null"]},
        "notes": {"type": "string"},
    },
}


def unit_crop(width: int, height: int) -> Image.Image:
    """Colour frame at the given size, cropped to the calibrated area plus margin."""
    img = Image.open(io.BytesIO(snap.capture(width, height))).convert("RGB")
    cfg = ac.load_config()
    if cfg is None:
        return img
    scale = width / 1280
    x0, y0, x1, y1 = (v * scale for v in cfg["roi"])
    mx, my = (x1 - x0) * 0.6, (y1 - y0) * 0.4
    return img.crop((int(max(0, x0 - mx)), int(max(0, y0 - my)),
                     int(min(width, x1 + mx)), int(min(height, y1 + my))))


def jpeg(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=88)
    return buf.getvalue()


def openai_describe(image: bytes) -> dict:
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        raise LookupError("OPENAI_API_KEY is not set on the Pi")
    body = {
        "model": OPENAI_MODEL,
        "input": [{"role": "user", "content": [
            {"type": "input_text", "text": DESCRIBE_PROMPT},
            {"type": "input_image", "image_url": "data:image/jpeg;base64," + base64.b64encode(image).decode()},
        ]}],
        "text": {"format": {"type": "json_schema", "name": "ac_state", "strict": True, "schema": DESCRIBE_SCHEMA}},
    }
    req = urllib.request.Request(
        "https://api.openai.com/v1/responses", data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        out = json.load(resp)
    for item in out.get("output", []):
        for part in item.get("content") or []:
            if part.get("type") == "output_text":
                return json.loads(part["text"])
    raise RuntimeError("OpenAI returned no text output")


class Handler(BaseHTTPRequestHandler):
    server_version = "acd/1"

    def log_message(self, fmt, *args):  # one line per request, no bodies
        sys.stderr.write(f"{self.headers.get('Tailscale-User-Login', '-')} {fmt % args}\n")

    def send_json(self, status: int, payload: dict) -> None:
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def authorised(self) -> bool:
        login = self.headers.get("Tailscale-User-Login")
        if login and (not ALLOWED or login in ALLOWED):
            return True
        self.send_json(HTTPStatus.FORBIDDEN, {"error": "only reachable through tailscale serve"})
        return False

    def body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(length) or b"{}")

    def do_GET(self):
        if not self.authorised():
            return
        path, _, query = self.path.partition("?")
        if path == "/api/status":
            cfg = ac.load_config()
            if cfg is None:
                return self.send_json(HTTPStatus.CONFLICT, {"error": "not calibrated; run `ac calibrate` on the Pi"})
            with ac.device_lock():
                state, c_on, c_off = ac.classify(ac.frame(), cfg)
            return self.send_json(HTTPStatus.OK, {"state": state, "match_on": round(c_on, 3),
                                                   "match_off": round(c_off, 3), "at": int(time.time())})
        if path == "/api/snapshot":
            with ac.device_lock():
                if "full=1" in query:
                    img = Image.open(io.BytesIO(snap.capture())).convert("RGB")
                else:
                    img = unit_crop(1920, 1080)
            data = jpeg(img)
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)
            return
        self.send_json(HTTPStatus.NOT_FOUND, {"error": "not found"})

    def do_POST(self):
        if not self.authorised():
            return
        try:
            req = self.body()
        except json.JSONDecodeError:
            return self.send_json(HTTPStatus.BAD_REQUEST, {"error": "body must be JSON"})
        if self.path == "/api/command":
            try:
                code, want, label = ac.command(req.get("action", ""), req.get("temp"))
            except ValueError as e:
                return self.send_json(HTTPStatus.BAD_REQUEST, {"error": str(e)})
            with ac.device_lock():
                rc, message = ac.switch(code, want, label)
            return self.send_json(HTTPStatus.OK, {"ok": rc == 0, "verified": rc != 2,
                                                   "expected": want, "message": message})
        if self.path == "/api/describe":
            with ac.device_lock():
                image = jpeg(unit_crop(1920, 1080))
            try:
                result = openai_describe(image)
            except LookupError as e:
                return self.send_json(HTTPStatus.SERVICE_UNAVAILABLE, {"error": str(e)})
            except urllib.error.HTTPError as e:
                detail = e.read().decode(errors="replace")[:300]
                return self.send_json(HTTPStatus.BAD_GATEWAY, {"error": f"OpenAI {e.code}: {detail}"})
            except (urllib.error.URLError, RuntimeError, json.JSONDecodeError) as e:
                return self.send_json(HTTPStatus.BAD_GATEWAY, {"error": f"OpenAI request failed: {e}"})
            return self.send_json(HTTPStatus.OK, {**result, "model": OPENAI_MODEL})
        self.send_json(HTTPStatus.NOT_FOUND, {"error": "not found"})


def main() -> int:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"acd listening on http://{HOST}:{PORT}", file=sys.stderr)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
