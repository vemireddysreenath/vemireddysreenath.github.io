# MVP1 Mac CAN Monitor

Reads the CSV frame/status stream from the ESP32-S3 over USB serial, displays it, tracks
per-ID counts and frequency, and optionally logs the raw stream for later replay (MVP2).

## Setup

```bash
cd automotive-can/tools/mac-monitor
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Usage

```bash
# Auto-detect the port and start monitoring
python3 can_monitor.py

# List available serial ports
python3 can_monitor.py --list-ports

# Specify the port explicitly
python3 can_monitor.py --port /dev/cu.usbmodem14201

# Only display specific CAN IDs (log/capture is unaffected — always complete)
python3 can_monitor.py --filter 0x123,0x245

# Save the raw, unfiltered stream to a file (for later replay/analysis)
python3 can_monitor.py --log capture_2026-08-28.csv

# High-rate bus: suppress per-frame lines, show a live summary instead
python3 can_monitor.py --quiet
```

Exit with `Ctrl-C` — prints a summary table (per-ID count, frequency, DLC) before exiting.

## Example output

```
CAN MONITOR
Port: /dev/cu.usbmodem14201  Baud: 115200

Timestamp       ID       DLC       Data
-----------------------------------------------------
12:31:22.123    123      8         40 1A 00 7F 02 00 00 00
12:31:22.124    245      8         00 00 81 2A 04 10 00 00
^C
=======================================================
SUMMARY
Duration: 12.4s   Total frames: 5238   Overall rate: 422.4 Hz   Parse errors: 0

ID         Count      Hz       DLC
0x123      2604       210.2    8
0x245      2634       212.5    8

Last firmware status: STATS uptime_ms=13000 rx=5238 dropped=0 driver_missed=0 driver_overrun=0 bus_errors=0 arb_lost=0 tx_err_ctr=0 rx_err_ctr=0 rate_hz=421.3 state=RUNNING
```

`Timestamp` in the live table is the Mac's receipt time (for a human watching); the
authoritative per-frame time is the device's `timestamp_us`, which is what gets written to
`--log` files unchanged, straight from the firmware.

Lines starting with `#` from the firmware (banner, `#STATS ...`) print as `[FW] ...` inline —
they're not CAN frames and are handled separately from the CSV parser.

Only dependency: `pyserial`. The parsing/formatting logic (`parse_frame`, `format_id`, filter
parsing) was unit-tested against synthetic input matching the firmware's exact output format;
it has not yet been run against the real device — that's the point of the test procedure in
`../../README.md`.
