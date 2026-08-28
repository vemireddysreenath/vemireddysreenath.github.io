#pragma once

#include "driver/gpio.h"
#include "driver/twai.h"

// ---------------------------------------------------------------------------
// MVP1 CAN bus configuration
//
// Bitrate: vehicles vary. Start at 500 kbps (typical HS-CAN / SAE J2284 on
// OBD-II pins 6/14). If no valid frames appear and bus_errors keeps
// climbing in the #STATS line, try 250 kbps, then 125 kbps: change
// SELECTED_BITRATE below, reflash, and re-test. See ../../README.md
// "How to verify CAN bitrate".
// ---------------------------------------------------------------------------

namespace CanConfig {

// ESP32-S3 <-> SN65HVD230 wiring (full table in ../../README.md).
// GPIO17/18 are general-purpose pins on the DevKitC-1, not used by the
// native USB (19/20) or PSRAM/flash -- confirm against your board's
// silkscreen before wiring.
constexpr gpio_num_t TX_GPIO = GPIO_NUM_17;  // ESP32 TWAI TX -> SN65HVD230 TXD
constexpr gpio_num_t RX_GPIO = GPIO_NUM_18;  // SN65HVD230 RXD -> ESP32 TWAI RX

enum class Bitrate { KBPS_125, KBPS_250, KBPS_500 };

// <<< Change this line to test other bitrates, then reflash >>>
constexpr Bitrate SELECTED_BITRATE = Bitrate::KBPS_500;

inline twai_timing_config_t timingConfig() {
    switch (SELECTED_BITRATE) {
        case Bitrate::KBPS_125: { twai_timing_config_t t = TWAI_TIMING_CONFIG_125KBITS(); return t; }
        case Bitrate::KBPS_250: { twai_timing_config_t t = TWAI_TIMING_CONFIG_250KBITS(); return t; }
        case Bitrate::KBPS_500:
        default:                { twai_timing_config_t t = TWAI_TIMING_CONFIG_500KBITS(); return t; }
    }
}

inline const char* bitrateLabel() {
    switch (SELECTED_BITRATE) {
        case Bitrate::KBPS_125: return "125 kbps";
        case Bitrate::KBPS_250: return "250 kbps";
        case Bitrate::KBPS_500:
        default:                return "500 kbps";
    }
}

constexpr uint32_t DRIVER_RX_QUEUE_LEN = 64;    // TWAI driver's internal RX queue (frames)
constexpr uint32_t SW_RING_BUFFER_LEN  = 1024;  // Our own app-level ring buffer (frames)

}  // namespace CanConfig
