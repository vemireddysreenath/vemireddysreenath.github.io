#!/usr/bin/env python3
"""MVP1 CAN monitor.

Reads the CSV frame/status stream the ESP32-S3 firmware writes to USB
serial, displays it, tracks per-ID counts and frequency, optionally
filters the live display by CAN ID, and optionally saves the raw
(unfiltered) stream to a log file for later analysis/replay (MVP2).

Usage:
    python3 can_monitor.py                          # auto-detect port
    python3 can_monitor.py --port /dev/cu.usbmodem14201
    python3 can_monitor.py --filter 0x123,0x245      # only display these IDs
    python3 can_monitor.py --log capture_2026-08-28.csv
    python3 can_monitor.py --list-ports
"""

import argparse
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    sys.exit("pyserial is required: pip install -r requirements.txt")

FRAME_HEADER = "timestamp_us,id,dlc,data"
FLUSH_EVERY_N_LINES = 50


@dataclass
class Frame:
    ts_us: int
    can_id: int
    dlc: int
    data: bytes
    extended: bool


@dataclass
class IdStats:
    count: int = 0
    first_ts_us: int = 0
    last_ts_us: int = 0
    dlc_seen: set = field(default_factory=set)
    extended: bool = False


class StatsTracker:
    def __init__(self):
        self.start_time = time.time()
        self.total_frames = 0
        self.parse_errors = 0
        self.by_id = {}
        self.last_fw_status_line = None
        self._last_live_print = 0.0

    def record(self, frame: Frame):
        self.total_frames += 1
        e = self.by_id.get(frame.can_id)
        if e is None:
            e = IdStats(first_ts_us=frame.ts_us, extended=frame.extended)
            self.by_id[frame.can_id] = e
        e.count += 1
        e.last_ts_us = frame.ts_us
        e.dlc_seen.add(frame.dlc)


def format_id(can_id: int, extended: bool) -> str:
    return f"{can_id:08X}" if extended else f"{can_id:03X}"


def parse_frame(line: str):
    parts = line.split(",", 3)
    if len(parts) != 4:
        return None
    try:
        ts_us = int(parts[0])
        can_id = int(parts[1], 16)
        dlc = int(parts[2])
        data_str = parts[3].strip()
        data = bytes(int(b, 16) for b in data_str.split()) if data_str else b""
        extended = len(parts[1]) > 5  # "0x123" = 5 chars, "0x0000ABCD" > 5
        return Frame(ts_us=ts_us, can_id=can_id, dlc=dlc, data=data, extended=extended)
    except (ValueError, IndexError):
        return None


def parse_filter(filter_arg):
    if not filter_arg:
        return None
    ids = set()
    for tok in filter_arg.split(","):
        tok = tok.strip()
        if tok:
            ids.add(int(tok, 16))
    return ids


def list_ports():
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return ports
    print("Available serial ports:")
    for p in ports:
        print(f"  {p.device}  ({p.description})")
    return ports


def autodetect_port():
    markers = ("usbmodem", "usbserial", "SLAB_USB", "wchusbserial")
    return [p for p in serial.tools.list_ports.comports()
            if any(m in p.device for m in markers)]


def resolve_port(args):
    if args.port:
        return args.port
    candidates = autodetect_port()
    if len(candidates) == 1:
        print(f"Auto-detected port: {candidates[0].device}")
        return candidates[0].device
    print("Could not auto-detect a single ESP32 port.")
    list_ports()
    print("Specify one with --port /dev/cu.XXXX")
    sys.exit(1)


def print_frame(frame: Frame):
    now = datetime.now()
    host_ts = now.strftime("%H:%M:%S.%f")[:-3]
    data_str = " ".join(f"{b:02X}" for b in frame.data)
    print(f"{host_ts:<15} {format_id(frame.can_id, frame.extended):<8} {frame.dlc:<9} {data_str}")


def print_live_status(stats: StatsTracker, force=False):
    now = time.time()
    if not force and now - stats._last_live_print < 0.25:
        return
    stats._last_live_print = now
    elapsed = now - stats.start_time
    rate = stats.total_frames / elapsed if elapsed > 0 else 0.0
    sys.stdout.write(
        f"\rFrames: {stats.total_frames:<8} IDs: {len(stats.by_id):<5} "
        f"Rate: {rate:6.1f} Hz   Parse errors: {stats.parse_errors:<5}"
    )
    sys.stdout.flush()


def print_summary(stats: StatsTracker):
    elapsed = time.time() - stats.start_time
    overall_hz = stats.total_frames / elapsed if elapsed > 0 else 0.0
    print("=" * 55)
    print("SUMMARY")
    print(f"Duration: {elapsed:.1f}s   Total frames: {stats.total_frames}   "
          f"Overall rate: {overall_hz:.1f} Hz   Parse errors: {stats.parse_errors}")
    print()
    if stats.by_id:
        print(f"{'ID':<10} {'Count':<10} {'Hz':<8} {'DLC'}")
        for can_id, e in sorted(stats.by_id.items(), key=lambda kv: -kv[1].count):
            span_s = max((e.last_ts_us - e.first_ts_us) / 1e6, 1e-6)
            hz = e.count / span_s if e.count > 1 else 0.0
            dlc_display = str(next(iter(e.dlc_seen))) if len(e.dlc_seen) == 1 else f"varies {sorted(e.dlc_seen)}"
            print(f"0x{format_id(can_id, e.extended):<8} {e.count:<10} {hz:<8.1f} {dlc_display}")
    if stats.last_fw_status_line:
        print()
        print(f"Last firmware status: {stats.last_fw_status_line}")


def parse_args():
    p = argparse.ArgumentParser(description="MVP1 CAN monitor: reads CAN frames from the ESP32-S3 over USB serial.")
    p.add_argument("--port", help="Serial device, e.g. /dev/cu.usbmodem14201 (auto-detected if omitted)")
    p.add_argument("--baud", type=int, default=115200)
    p.add_argument("--filter", help="Comma-separated CAN IDs to display, hex, e.g. 123,245 or 0x123,0x245. "
                                     "Only affects the live display -- --log always captures everything.")
    p.add_argument("--log", help="Path to save the raw, unfiltered frame/status stream (replayable in MVP2)")
    p.add_argument("--quiet", action="store_true", help="Suppress per-frame lines; show a live summary line instead")
    p.add_argument("--list-ports", action="store_true", help="List available serial ports and exit")
    return p.parse_args()


def main():
    args = parse_args()
    if args.list_ports:
        list_ports()
        return

    id_filter = parse_filter(args.filter)
    port = resolve_port(args)

    try:
        ser = serial.Serial(port=port, baudrate=args.baud, timeout=1)
    except serial.SerialException as exc:
        sys.exit(f"Could not open {port}: {exc}")
    time.sleep(0.5)  # let the board settle after the DTR-triggered reset on open

    log_file = None
    if args.log:
        log_file = open(args.log, "w")
        log_file.write(f"# capture_start_local={datetime.now().isoformat()}\n")
        log_file.write(f"# port={port} baud={args.baud}\n")

    stats = StatsTracker()

    print("CAN MONITOR")
    print(f"Port: {port}  Baud: {args.baud}" + (f"  Filter: {sorted(hex(i) for i in id_filter)}" if id_filter else ""))
    print()
    if not args.quiet:
        print(f"{'Timestamp':<15} {'ID':<8} {'DLC':<9} Data")
        print("-" * 55)

    lines_since_flush = 0
    try:
        while True:
            raw = ser.readline()
            if not raw:
                continue
            line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
            if not line:
                continue

            if log_file:
                log_file.write(line + "\n")
                lines_since_flush += 1
                if lines_since_flush >= FLUSH_EVERY_N_LINES:
                    log_file.flush()
                    lines_since_flush = 0

            if line.startswith("#"):
                text = line.lstrip("#").strip()
                if text.startswith("STATS"):
                    stats.last_fw_status_line = text
                print(f"[FW] {text}")
                continue
            if line == FRAME_HEADER:
                continue

            frame = parse_frame(line)
            if frame is None:
                stats.parse_errors += 1
                continue

            stats.record(frame)
            if id_filter and frame.can_id not in id_filter:
                continue

            if args.quiet:
                print_live_status(stats)
            else:
                print_frame(frame)
    except KeyboardInterrupt:
        pass
    except serial.SerialException as exc:
        print(f"\nSerial error (device unplugged?): {exc}")
    finally:
        if log_file:
            log_file.flush()
            log_file.close()
        ser.close()
        print()
        print_summary(stats)


if __name__ == "__main__":
    main()
