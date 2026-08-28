# MVP1 Firmware

ESP32-S3 TWAI (CAN) listen-only receiver. Full wiring table, safety checklist, build/flash/
monitor commands, expected output, and troubleshooting live in
[`../README.md`](../README.md) — this file is just a quick reference once you've read that.

```bash
pio run --target upload      # build + flash
pio device monitor -b 115200 # serial monitor (Ctrl-C to exit)
```

Bitrate is set in `src/can/can_config.h` (`CanConfig::SELECTED_BITRATE`) — default 500 kbps, see
`../README.md` §13 if you need to try 250/125 kbps instead.

Safety invariant: `TWAI_MODE_LISTEN_ONLY` in `src/can/can_manager.cpp`. `twai_transmit()` is not
called anywhere in this tree — see `../README.md` §15 to verify.
