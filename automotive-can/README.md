# Automotive CAN Project — MVP1: Raw CAN Reception

```
MVP1 = SEE        <- you are here
MVP2 = UNDERSTAND
MVP3 = CONNECT
MVP4 = CONTROL CAREFULLY
```

MVP1 is strictly **read-only**. Goal:

```
CAR -> OBD-II J1962 Pigtail -> SN65HVD230 -> ESP32-S3 -> USB-C -> MacBook -> raw CAN frames
```

Status: firmware and Mac tool are written below and have **not been hardware-tested yet** —
this sandbox has no ESP32, no PlatformIO toolchain, and no vehicle. Only the Mac-side
Python logic was unit-tested here (synthetic input, see `tools/mac-monitor/`). You need to
build, flash, and run the procedure at the bottom of this file, then send me the actual
serial output. Per the project rules, we don't move to MVP2 until you confirm MVP1 works
against real hardware.

---

## 1. Architecture

```
                  listen-only, 500 kbps (configurable)
CAR ── CAN-H/L ──> SN65HVD230 ── TWAI ──> ESP32-S3 ── USB-C ──> Mac
                                            │
                                            ├── canRxTask (high priority)
                                            │     blocks on twai_receive(),
                                            │     pushes into a 1024-frame
                                            │     FreeRTOS queue (ring buffer)
                                            │
                                            └── loop() (USB writer)
                                                  drains the ring buffer,
                                                  writes CSV to Serial,
                                                  prints #STATS 1x/sec
```

Two FreeRTOS tasks, one queue between them. That's the whole point of the ring buffer:
`canRxTask` never waits on `Serial` — if USB output stalls, frames pile up in the queue
(up to 1024) instead of being lost at the driver level. Only if the queue itself fills up
(sustained USB stall) do we start counting `dropped` frames — and we count it rather than
silently losing it.

CAN and USB are also separated at the type level: `CanManager` (`can/`) knows nothing about
Serial, and `USBTransport` (`transport/`) knows nothing about TWAI — they only share the
`CanFrame` struct through the `FrameTransport` interface. This is so that adding
`BLETransport`/`WiFiTransport` in MVP3 touches `transport/` only, never `can/`.

---

## 2. Wiring (exact table)

**Verify these against your actual boards' silkscreen before connecting anything** — SN65HVD230
breakout boards from different sellers label pins in different orders, and some add extra pins
(RS/SLP, VREF, an onboard termination jumper) not listed here.

### OBD-II J1962 pigtail → SN65HVD230

| OBD-II Pin | Signal | → | SN65HVD230 Pin |
|---|---|---|---|
| 6 | CAN-H | → | CANH |
| 14 | CAN-L | → | CANL |
| 4 | Chassis Ground | → | GND |
| 5 | Signal Ground | (not used in MVP1 — pin 4 alone is sufficient) | |
| 16 | Vehicle +12V | | **DO NOT CONNECT** |

### ESP32-S3 DevKitC-1 → SN65HVD230

| ESP32-S3 | → | SN65HVD230 |
|---|---|---|
| 3V3 | → | 3.3V (**not** 5V — confirm your board's VCC rating; SN65HVD230 is a 3.3V part) |
| GND | → | GND |
| GPIO17 | → | TXD |
| GPIO18 | ← | RXD |

If your SN65HVD230 board breaks out an **RS/SLP** pin: tie it to GND for normal (high-speed)
operation. Floating or high on that pin puts the transceiver in slope-control/low-power mode,
which can look like "no frames" or corrupted frames even with correct wiring and bitrate. If
your board has a solder jumper or switch for an **onboard 120Ω termination resistor**, leave it
open/disabled — the vehicle's own ECUs already terminate the bus at both ends; adding a third
termination point degrades signal integrity rather than helping it.

---

## 3. ESP32-S3 GPIO configuration

- `GPIO17` = TWAI TX (controller → transceiver TXD)
- `GPIO18` = TWAI RX (transceiver RXD → controller)

Both are general-purpose pins on the DevKitC-1 — not the native-USB pins (GPIO19/20) and not
used by flash/PSRAM strapping. They're set in exactly one place, `firmware/src/can/can_config.h`,
not hardcoded elsewhere. TX stays wired even though MVP1 never transmits: in
`TWAI_MODE_LISTEN_ONLY` the controller holds the line recessive and the peripheral is physically
prevented from driving it dominant (see §15).

---

## 4. Framework: PlatformIO + Arduino, ESP-IDF TWAI driver directly

- **PlatformIO** gives a reproducible CLI build/flash/monitor workflow on macOS without hand-
  installing the full ESP-IDF toolchain and its submodules — one `pio run` and it fetches the
  right compiler and framework version for `esp32-s3-devkitc-1`.
- **Arduino framework**, because for MVP1 we only need `Serial` + two FreeRTOS tasks — ESP-IDF's
  own project scaffolding (`idf.py`, `sdkconfig`, component `CMakeLists.txt`) is more ceremony
  than this stage needs.
- We call **`driver/twai.h` directly** (Espressif's real ESP-IDF driver, bundled inside the
  Arduino-ESP32 core) rather than a third-party CAN wrapper library, because MVP1's safety
  requirements — listen-only mode, exact bitrate control, per-driver error counters — need the
  real API surface, not a simplified wrapper that might hide the mode flag.
- **Zero external libraries.** Only the board platform itself.
- This keeps the door open to a pure ESP-IDF rewrite later (MVP3/4, if BLE security work needs
  it) without cost: the CAN logic already speaks raw ESP-IDF, only `main.cpp`/`Serial` calls are
  Arduino-specific.

---

## 5. Project folder structure

```
automotive-can/
├── README.md                    <- this file
├── firmware/
│   ├── platformio.ini
│   └── src/
│       ├── main.cpp              wires CanManager + USBTransport together
│       ├── can/
│       │   ├── can_frame.h       shared CanFrame struct
│       │   ├── can_config.h      GPIO pins, bitrate selection
│       │   ├── can_manager.h
│       │   └── can_manager.cpp   TWAI init (listen-only), rx task, ring buffer, stats
│       └── transport/
│           ├── transport.h       FrameTransport interface
│           ├── usb_transport.h
│           └── usb_transport.cpp CSV-over-serial output
└── tools/
    └── mac-monitor/
        ├── can_monitor.py        Mac-side CAN monitor (see its own README)
        ├── requirements.txt
        └── README.md
```

No `transport/ble_transport.*`, `transport/wifi_transport.*`, or `security/` yet — those are
MVP3 and don't exist until then, per the project's read-only/one-MVP-at-a-time rules.

---

## 6. Firmware — what each file does

- **`can/can_frame.h`** — the common `CanFrame` struct (timestamp_us, can_id, dlc, flags, data[8]).
  Classic CAN only; the ESP32-S3's TWAI controller isn't CAN-FD capable, so this isn't a
  simplification, it's the hardware.
- **`can/can_config.h`** — GPIO pin assignment, and the bitrate switch (`SELECTED_BITRATE`) you'll
  change if 500 kbps doesn't show valid traffic (§13).
- **`can/can_manager.cpp`** — `begin()` installs the TWAI driver with
  `TWAI_MODE_LISTEN_ONLY` (the safety invariant — see §15) and an accept-all filter (§ "Initial
  filter" in the project spec: accept everything for discovery). `rxTaskLoop()` blocks on
  `twai_receive()` and pushes each frame into our own 1024-entry ring buffer. `getStats()` merges
  our own counters with `twai_get_status_info()` (bus errors, RX-queue-full/overrun counts, TX/RX
  error counters).
- **`transport/usb_transport.cpp`** — formats frames as CSV
  (`timestamp_us,id,dlc,data`, e.g. `1234567,0x123,8,40 1A 00 7F 02 00 00 00`) and status/stats as
  `#`-prefixed comment lines, once a second.
- **`main.cpp`** — `setup()` starts USB, starts the TWAI driver, and launches `canRxTask` at high
  priority. `loop()` drains the ring buffer to USB and prints stats every second.

Frame line format matches the project spec exactly:
```
timestamp_us,id,dlc,data
123456,0x123,8,40 1A 00 7F 02 00 00 00
```
`#`-prefixed lines (banner, `#STATS ...`) are comments — the Mac tool and any future parser
should skip/handle them separately from frame data.

---

## 7. macOS setup commands

```bash
# Option A: pipx (recommended by PlatformIO's own docs)
brew install pipx
pipx ensurepath
pipx install platformio

# Option B: Homebrew directly
brew install platformio

# Verify
pio --version
```

---

## 8. Flashing commands

```bash
cd automotive-can/firmware

# See which serial port shows up when the board is plugged in
ls /dev/cu.*

# Build + flash (auto-detects the port if there's only one candidate)
pio run --target upload

# Or specify the port explicitly if auto-detect picks the wrong one
pio run --target upload --upload-port /dev/cu.usbmodemXXXXX
```

---

## 9. Serial-monitor commands

```bash
cd automotive-can/firmware

pio device monitor -b 115200
# or, in one shot after flashing:
pio run --target upload --target monitor

# to exit: Ctrl-C
```

Alternative without PlatformIO: `screen /dev/cu.usbmodemXXXXX 115200` (exit: `Ctrl-A` then `K`).

---

## 10. Expected output

**Step 1-2 (USB + transceiver wired, vehicle NOT yet connected):**
```
# MVP1 CAN monitor - ESP32-S3 + SN65HVD230
# Mode: LISTEN-ONLY (CAN RX = YES, CAN TX = NO)
# Bitrate: 500 kbps
# TX_GPIO=17 RX_GPIO=18
# TWAI driver started (listen-only, accept-all filter)
timestamp_us,id,dlc,data
#STATS uptime_ms=1000 rx=0 dropped=0 driver_missed=0 driver_overrun=0 bus_errors=0 arb_lost=0 tx_err_ctr=0 rx_err_ctr=0 rate_hz=0.0 state=RUNNING
```
This is the **correct** result at this stage: zero frames (nothing is transmitting on an
unconnected bus), `state=RUNNING`, all error counters at 0. That combination proves the driver
came up cleanly in listen-only mode — see it before moving to Step 3.

**Step 3-4 (connected to vehicle, ignition on, correct bitrate):**
```
timestamp_us,id,dlc,data
1234567,0x123,8,40 1A 00 7F 02 00 00 00
1234789,0x245,8,00 00 81 2A 04 10 00 00
1235012,0x123,8,40 1A 00 7F 02 00 00 01
...
#STATS uptime_ms=13000 rx=842 dropped=0 driver_missed=0 driver_overrun=0 bus_errors=0 arb_lost=0 tx_err_ctr=0 rx_err_ctr=0 rate_hz=421.3 state=RUNNING
```

**Wrong bitrate / bad wiring signature** (see §13):
```
#STATS uptime_ms=5000 rx=0 dropped=0 driver_missed=0 driver_overrun=0 bus_errors=187 arb_lost=0 tx_err_ctr=0 rx_err_ctr=96 rate_hz=0.0 state=RUNNING
```
`bus_errors` and `rx_err_ctr` climbing steadily with `rx=0` is the signature to look for.

---

## 11. Hardware safety checklist

- [ ] SN65HVD230 VCC goes to ESP32 **3V3**, never 5V — confirm your board's actual rating.
- [ ] OBD-II **Pin 16 (+12V) is never connected** to anything, ever, in MVP1.
- [ ] ESP32-S3 is powered **only** via USB-C from the Mac during MVP1. Not from Pin 16, not from
      any other vehicle supply.
- [ ] Common ground is connected: OBD-II Pin 4 → SN65HVD230 GND → ESP32 GND.
- [ ] CAN-H and CAN-L are not swapped (Pin 6 → CANH, Pin 14 → CANL). Swapping doesn't damage
      anything but the bus won't decode correctly.
- [ ] RS/SLP pin (if present on your board) is grounded for normal-speed operation.
- [ ] Onboard termination jumper (if present) is **open/disabled** — the vehicle already
      terminates the bus.
- [ ] Verify your actual OBD-II pigtail's pin numbering with a multimeter before trusting any
      printed label — pinout mistakes on a passive listen-only tap are low-risk to the vehicle,
      but confirm anyway.
- [ ] Do Steps 1-2 (USB, then ESP32+transceiver) completely **before** touching the vehicle.
- [ ] Connect to the vehicle with ignition off first; power the vehicle up only after wiring is
      verified.
- [ ] Confirm the firmware banner prints `Mode: LISTEN-ONLY` (§14) before your first vehicle
      connection.

---

## 12. Troubleshooting: no CAN frames appear

1. Re-check wiring continuity (multimeter): CANH/CANL/GND against the pigtail's actual pinout.
2. Confirm the vehicle's ignition is ON or ACC — many vehicles go quiet on CAN when fully off.
3. Confirm 3.3V is actually present at the SN65HVD230's VCC pin (multimeter).
4. Confirm RS/SLP is grounded, if your board has that pin.
5. Try the other bitrates systematically — see §13.
6. Confirm TX/RX aren't swapped: ESP32 GPIO17 → SN65 **TXD**, SN65 **RXD** → ESP32 GPIO18.
7. Check the serial banner: if you see `FATAL: TWAI driver init failed`, that's a driver/GPIO
   config problem, not a bus problem — send me that output.
8. Check the `#STATS` line: `bus_errors` incrementing with `rx=0` points at bitrate or wiring, not
   "no traffic" — see §13.
9. Confirm you're on Pin 6/14 (SAE J1962 standard HS-CAN location). Any vehicle from
   ~2008+ (US) has CAN here; if you're on an unusual/older vehicle, verify it actually uses CAN
   on the OBD-II connector at all.

Send me the actual `#STATS` lines and a sample of raw output rather than a description — this
project runs on real logs, not guesses.

---

## 13. How to verify CAN bitrate

Change `CanConfig::SELECTED_BITRATE` in `firmware/src/can/can_config.h`, reflash, and reconnect
to the vehicle. Try in this order: **500 kbps → 250 kbps → 125 kbps**.

- **Correct bitrate**: steady stream of frames, `rx` climbing in `#STATS`, `bus_errors` staying
  at or near 0, DLC values that look plausible (commonly 8), the same CAN IDs reappearing at
  roughly steady intervals.
- **Wrong bitrate**: `bus_errors`/`rx_err_ctr` climb continuously and `rx` stays at 0 — at a
  mismatched bitrate, CRC/bit-stuffing fails almost every time, so you get error counters
  incrementing, essentially never valid frames. (You will not usually see "garbage but
  parseable" frames at the wrong rate — the failure mode is errors, not corrupted-but-readable
  data.)
- If none of the three standard rates show clean traffic, wiring/grounding is the more likely
  culprit — recheck §11/§12 before assuming an unusual bitrate.
- If you have access to the vehicle's factory service manual or wiring diagram, it will usually
  state the HS-CAN bitrate directly (most 2008+ vehicles: 500 kbps per SAE J2284).

---

## 14. How to verify the ESP32 is actually in listen-only mode

Three independent checks:

1. **Source**: `firmware/src/can/can_manager.cpp` passes `TWAI_MODE_LISTEN_ONLY` to
   `TWAI_GENERAL_CONFIG_DEFAULT(...)` and then asserts `g_config.mode == TWAI_MODE_LISTEN_ONLY`
   before continuing — if that ever fails, `begin()` returns `false` and firmware halts with
   `FATAL: TWAI driver init failed` instead of silently running in a different mode.
2. **Runtime**: the serial banner prints `# Mode: LISTEN-ONLY (CAN RX = YES, CAN TX = NO)` at
   boot, straight from that same config — if you see it, the driver was installed with that flag.
3. **Hardware** (optional, strongest evidence): probe GPIO17 (SN65HVD230 TXD input) with a
   multimeter or logic analyzer while frames are being received — it should show no transitions
   at all. A transmitting node's TX line toggles on every frame it sends; a listen-only node's
   never does.

---

## 15. How to verify no CAN transmission is occurring

- **Code-level guarantee**: `twai_transmit()` is not called anywhere in this codebase. You can
  confirm with `grep -rn twai_transmit firmware/src` — expect zero matches. MVP1 does not expose
  a transmit function at all (no `send_can_frame()`/`inject_can()`/`transmit_can()` anywhere),
  so there's no code path that could accidentally fire one.
- **Peripheral-level guarantee**: `TWAI_MODE_LISTEN_ONLY` is enforced by the ESP32-S3's TWAI
  peripheral itself, not just by our software choosing not to call transmit — in this mode the
  controller cannot ACK or arbitrate for the bus even if instructed to. This is why
  `tx_error_counter` in `#STATS` should read `0` permanently: a node actively arbitrating for bus
  access accumulates TX errors under contention; a listen-only node never attempts arbitration; if you ever see it increase, treat that as a code regression, not a bus condition, and stop testing
  until it's understood.
- **Hardware check** (optional, strongest evidence): same as §14's oscilloscope/logic-analyzer
  check on GPIO17 — no transitions, no exceptions.

---

## Mac monitor tool

See `tools/mac-monitor/README.md` for setup and usage. Quick start:

```bash
cd automotive-can/tools/mac-monitor
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 can_monitor.py
```

---

## Test procedure — please run this and send me the actual output

1. **Step 1 (USB only)**: flash with the vehicle *disconnected*. Confirm you see the banner,
   `Mode: LISTEN-ONLY`, the driver-started line, and `#STATS` lines with `rx=0`, all counters 0,
   `state=RUNNING`. Send me this output.
2. **Step 2 (transceiver wired, vehicle still disconnected)**: same expected output as Step 1 —
   wiring the transceiver alone shouldn't change anything since nothing is driving the bus yet.
3. **Step 3-4 (vehicle connected)**: connect per §2, ignition ON, reflash if you changed nothing
   else. Run `can_monitor.py` (or the serial monitor) for at least 30 seconds. Send me:
   - The raw output (or `can_monitor.py --log capture.csv` output file)
   - The final `#STATS` line
   - Whether `can_monitor.py`'s summary table shows real, repeating CAN IDs
4. If step 3 shows zero frames or persistent `bus_errors`, work through §12 and §13, and send me
   what you tried and the resulting `#STATS` lines — I'll use that to figure out the next thing to
   try rather than guessing.

Once you confirm Step 3-4 works reliably against the actual vehicle, tell me and we'll start
MVP2 (decoding).
