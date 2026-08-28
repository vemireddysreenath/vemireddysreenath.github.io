#pragma once

#include <cstdint>

// Bit flags for CanFrame::flags
#define CAN_FLAG_EXTENDED 0x01  // 29-bit extended ID (vs. 11-bit standard)
#define CAN_FLAG_RTR      0x02  // Remote transmission request

// Common raw CAN frame representation shared across the CAN driver and
// every transport (USB now; BLE/Wi-Fi in later MVPs). Classic CAN only
// (max 8 data bytes) -- the ESP32-S3's built-in TWAI controller is not
// CAN-FD capable, so this is not a simplification we chose, it's what
// the hardware supports.
struct CanFrame {
    uint64_t timestamp_us;  // microseconds since boot (esp_timer_get_time())
    uint32_t can_id;
    uint8_t dlc;             // 0-8
    uint8_t flags;           // CAN_FLAG_* bitmask
    uint8_t data[8];
};
