#!/usr/bin/env python3
"""Drive an ElkSmart/Ocrustar USB IR blaster (045c:0195, D552) from Linux.

  irblaster probe                    handshake only, transmits nothing
  irblaster coolix off|on|coolNN|HEX send a Coolix (Midea R51-series) code;
                                     on = cool 17 C, fan auto
  irblaster learn NAME               record a remote's button into the codes file
  irblaster send NAME                transmit a recorded code
  irblaster list

Learning is unreliable on this dongle: a learn that times out leaves it
ignoring USB writes until it is power-cycled (replug, or reboot the Pi).

The USB framing, handshake, pulse compression and learn decoding are ported
from jdt1/tcl-ir and deadboy18/Ocrustar-USB-IR (MIT; see LICENSE-THIRD-PARTY).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from collections import Counter
from pathlib import Path

import usb.core
import usb.util

VID, PID = 0x045C, 0x0195
HELLO = bytes((0xFC,) * 4)
ACK = bytes((0xFA,) * 4)
LEARN_ON = bytes((0xFE,) * 4)
LEARN_OFF = bytes((0xFD,) * 4)
TX_PREAMBLE = bytes((0xFF,) * 4)
DEFAULT_FREQ = 38_000
# Learned codes are per-room data, so they live outside the repo.
CODES = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "pi-ac/codes.json"


# --- D552 encoding ----------------------------------------------------------


def mangle_byte(value: int) -> int:
    value &= 0xFF
    rev = 0
    for _ in range(8):
        rev = (rev << 1) | (value & 1)
        value >>= 1
    return (~rev) & 0xFF


def encode_timing(us: int, escape_ff: bool = False) -> list[int]:
    """Up to 2032 us: one byte of 16 us ticks; longer: a 7-bit LE varint of us."""
    if us <= 1:
        return [max(us, 0)]
    if us <= 2032:
        return [int(us / 16.0 + 0.5)]
    out = []
    while True:
        v = us & 0x7F
        us >>= 7
        if us:
            v |= 0x80
        if escape_ff and v == 0xFF:
            v = 0xFE
        out.append(v)
        if not us:
            return out


def compress_pulses(timings: list[int]) -> bytes:
    if len(timings) % 2:
        timings = [*timings, 10_000]
    pairs = [(max(timings[i], 0), max(timings[i + 1], 0)) for i in range(0, len(timings), 2)]
    common = [p for p, _ in Counter(pairs).most_common(2)]
    if len(common) == 1:
        common.append(common[0])
    common.sort(key=lambda p: p[0] + p[1])
    short_pair, long_pair = common
    out: list[int] = []
    for v in (*long_pair, *short_pair):
        out.extend(encode_timing(v, escape_ff=True))
    out.extend((0xFF, 0xFF, 0xFF))
    for p in pairs:
        if p == short_pair:
            out.append(0x00)
        elif p == long_pair:
            out.append(0x01)
        else:
            out.extend(encode_timing(p[0]))
            out.extend(encode_timing(p[1]))
    return bytes(out)


def frame_checksum(frame: bytes | bytearray) -> int:
    s = sum(frame[:62])
    return mangle_byte((s & 0xF0) | ((s >> 8) & 0x0F))


def encode_d552(freq: int, timings: list[int]) -> list[bytes]:
    if not 20_000 <= freq <= 100_000:
        raise ValueError("carrier frequency must be 20-100 kHz")
    if sum(timings) >= 1_000_000:
        raise ValueError("signal must be shorter than one second")
    payload = compress_pulses(timings)
    f = freq + 0x7FFFF
    msg = bytearray(TX_PREAMBLE)
    msg.extend((mangle_byte(f >> 8), mangle_byte(f >> 16), mangle_byte(f),
                mangle_byte(len(payload) >> 8), mangle_byte(len(payload))))
    msg.extend(payload)
    frames = []
    for off in range(0, len(msg), 62):
        fr = bytearray(msg[off:off + 62])
        if len(fr) == 62:
            fr.append(frame_checksum(fr))
        frames.append(bytes(fr))
    return frames


def decode_learned(payload: bytes) -> list[int]:
    timings, carry = [], 0
    for v in payload:
        if v == 0xFF:
            carry += 0xFF0
        else:
            timings.append(v * 16 + carry)
            carry = 0
    return timings


# --- Coolix (Midea R51-series remotes) ---------------------------------------


def coolix_timings(code: int) -> list[int]:
    """24 bits, each byte followed by its inverse, MSB first, sent twice.
    Timings follow IRremoteESP8266."""
    tick = 276
    hdr, bit, one, zero, gap = 17 * tick, 2 * tick, 6 * tick, 2 * tick, 19 * tick
    frame = [hdr, hdr]
    for shift in (16, 8, 0):
        byte = (code >> shift) & 0xFF
        for b in (byte, byte ^ 0xFF):
            for i in range(7, -1, -1):
                frame += [bit, one if b >> i & 1 else zero]
    frame += [bit, gap]
    return frame * 2


# State byte 2 holds the temperature (a Gray-like code for 17-30 C) and mode.
COOLIX_TEMP = {17: 0b0000, 18: 0b0001, 19: 0b0011, 20: 0b0010, 21: 0b0110, 22: 0b0111, 23: 0b0101,
               24: 0b0100, 25: 0b1100, 26: 0b1101, 27: 0b1001, 28: 0b1000, 29: 0b1010, 30: 0b1011}


def coolix_cool(temp: int) -> int:
    """Cool mode, fan auto, at temp C; any state command also powers the unit on."""
    return 0xB20000 | (0b101 << 5 | 0x1F) << 8 | COOLIX_TEMP[temp] << 4


COOLIX = {"off": 0xB27BE0, "on": coolix_cool(17), **{f"cool{t}": coolix_cool(t) for t in COOLIX_TEMP}}


# --- USB ----------------------------------------------------------------------


def read(ep_in, timeout: int) -> bytes | None:
    try:
        return bytes(ep_in.read(16_384, timeout=timeout))
    except usb.core.USBTimeoutError:
        return None


def open_device():
    dev = usb.core.find(idVendor=VID, idProduct=PID)
    if dev is None:
        sys.exit("IR blaster 045c:0195 not found")
    try:
        dev.reset()
        time.sleep(0.5)
        dev = usb.core.find(idVendor=VID, idProduct=PID) or dev
    except usb.core.USBError as e:
        if e.errno == 13:
            sys.exit("Permission denied on the USB device; install 70-irblaster.rules (setup.sh)")
    try:
        if dev.is_kernel_driver_active(0):
            dev.detach_kernel_driver(0)
    except (NotImplementedError, usb.core.USBError):
        pass
    dev.set_configuration()
    intf = dev.get_active_configuration()[(0, 0)]
    eps = [e for e in intf if usb.util.endpoint_type(e.bmAttributes) == usb.util.ENDPOINT_TYPE_BULK]
    ep_in = next(e for e in eps if usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_IN)
    ep_out = next(e for e in eps if usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_OUT)
    return dev, ep_in, ep_out


def handshake(ep_in, ep_out) -> bytes:
    while read(ep_in, 10):
        pass
    for _ in range(3):
        try:
            ep_out.write(HELLO, timeout=500)
        except usb.core.USBTimeoutError:
            sys.exit("IR blaster is not accepting writes; replug it (or reboot) to power-cycle it")
        for _ in range(5):
            r = read(ep_in, 200)
            if r and len(r) >= 6 and r[:4] == HELLO:
                ep_out.write(ACK, timeout=500)
                time.sleep(0.05)
                return r
    raise TimeoutError("IR blaster did not answer the handshake")


def learn(ep_in, ep_out, seconds: int) -> list[int]:
    ep_out.write(LEARN_ON, timeout=500)
    deadline = time.monotonic() + seconds
    expected, payload = None, bytearray()
    try:
        while time.monotonic() < deadline:
            pkt = read(ep_in, 300)
            if not pkt:
                continue
            if expected is None:
                if len(pkt) < 6 or pkt[:4] != LEARN_ON:
                    print(f"ignoring packet: {pkt.hex(' ').upper()}", file=sys.stderr)
                    continue
                expected = int.from_bytes(pkt[4:6], "big")
                payload.extend(pkt[6:])
            else:
                payload.extend(pkt)
            if expected is not None and len(payload) >= expected:
                return decode_learned(bytes(payload[:expected]))
    finally:
        try:
            ep_out.write(LEARN_OFF, timeout=500)
        except usb.core.USBError as e:
            print(f"stop-learn not accepted: {e}", file=sys.stderr)
    raise TimeoutError("no IR signal received; hold the remote within ~5 cm of the dongle")


def transmit(ep_in, ep_out, freq: int, timings: list[int]) -> bytes:
    for fr in encode_d552(freq, timings):
        if ep_out.write(fr, timeout=500) != len(fr):
            raise RuntimeError("short USB write")
        time.sleep(0.002)
    time.sleep(0.05)
    ack = read(ep_in, 500)
    if not ack or ack[:4] != TX_PREAMBLE:
        raise RuntimeError(f"no transmit acknowledgement ({ack!r})")
    return ack


# --- CLI ----------------------------------------------------------------------


def load_codes() -> dict:
    return json.loads(CODES.read_text()) if CODES.exists() else {}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("probe")
    sub.add_parser("list")
    lp = sub.add_parser("learn")
    lp.add_argument("name")
    lp.add_argument("--timeout", type=int, default=20)
    sp = sub.add_parser("send")
    sp.add_argument("name")
    cp = sub.add_parser("coolix")
    cp.add_argument("code")
    args = ap.parse_args()

    if args.cmd == "list":
        for name, c in load_codes().items():
            print(f"{name}: {len(c['timings'])} timings @ {c['freq']} Hz")
        print("coolix:", " ".join(COOLIX))
        return 0

    dev, ep_in, ep_out = open_device()
    try:
        r = handshake(ep_in, ep_out)
        print(f"handshake ok (signature {r[4:6].hex().upper()})")
        if args.cmd == "learn":
            print(f"Point the remote at the dongle and press the button for '{args.name}'...")
            t = learn(ep_in, ep_out, args.timeout)
            codes = load_codes()
            codes[args.name] = {"freq": DEFAULT_FREQ, "timings": t}
            CODES.parent.mkdir(parents=True, exist_ok=True)
            CODES.write_text(json.dumps(codes, indent=1))
            print(f"learned '{args.name}': {len(t)} timings, {sum(t) / 1000:.1f} ms")
        elif args.cmd == "send":
            c = load_codes()[args.name]
            ack = transmit(ep_in, ep_out, c["freq"], c["timings"])
            print(f"sent '{args.name}' (ack {ack.hex(' ').upper()})")
        elif args.cmd == "coolix":
            code = COOLIX.get(args.code) or int(args.code, 16)
            ack = transmit(ep_in, ep_out, DEFAULT_FREQ, coolix_timings(code))
            print(f"sent coolix 0x{code:06X} (ack {ack.hex(' ').upper()})")
    finally:
        usb.util.dispose_resources(dev)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
