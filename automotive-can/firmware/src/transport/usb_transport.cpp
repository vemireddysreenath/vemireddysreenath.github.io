#include "usb_transport.h"

#include <Arduino.h>
#include "../can/can_config.h"

bool USBTransport::begin() {
    Serial.begin(baud_);
    uint32_t start = millis();
    while (!Serial && millis() - start < 3000) {
        delay(10);
    }
    return true;
}

void USBTransport::printBanner() {
    Serial.println("# MVP1 CAN monitor - ESP32-S3 + SN65HVD230");
    Serial.println("# Mode: LISTEN-ONLY (CAN RX = YES, CAN TX = NO)");
    Serial.printf("# Bitrate: %s\n", CanConfig::bitrateLabel());
    Serial.printf("# TX_GPIO=%d RX_GPIO=%d\n", (int)CanConfig::TX_GPIO, (int)CanConfig::RX_GPIO);
    Serial.println("timestamp_us,id,dlc,data");
}

bool USBTransport::sendFrame(const CanFrame& frame) {
    char line[96];
    int len;

    if (frame.flags & CAN_FLAG_EXTENDED) {
        len = snprintf(line, sizeof(line), "%llu,0x%08lX,%u,",
                        (unsigned long long)frame.timestamp_us,
                        (unsigned long)frame.can_id, frame.dlc);
    } else {
        len = snprintf(line, sizeof(line), "%llu,0x%03lX,%u,",
                        (unsigned long long)frame.timestamp_us,
                        (unsigned long)frame.can_id, frame.dlc);
    }

    for (uint8_t i = 0; i < frame.dlc && i < 8 && len > 0 && (size_t)len < sizeof(line); i++) {
        len += snprintf(line + len, sizeof(line) - len, "%02X%s",
                         frame.data[i], (i + 1 < frame.dlc) ? " " : "");
    }

    Serial.println(line);
    return true;
}

void USBTransport::printStats(const CanStats& stats, float rateHz) {
    const char* stateStr = "STOPPED";
    switch (stats.state) {
        case TWAI_STATE_RUNNING:    stateStr = "RUNNING"; break;
        case TWAI_STATE_BUS_OFF:    stateStr = "BUS_OFF"; break;
        case TWAI_STATE_RECOVERING: stateStr = "RECOVERING"; break;
        default: break;
    }

    Serial.printf(
        "#STATS uptime_ms=%lu rx=%lu dropped=%lu driver_missed=%lu "
        "driver_overrun=%lu bus_errors=%lu arb_lost=%lu tx_err_ctr=%lu "
        "rx_err_ctr=%lu rate_hz=%.1f state=%s\n",
        (unsigned long)millis(), (unsigned long)stats.rx_frames,
        (unsigned long)stats.ring_dropped, (unsigned long)stats.driver_rx_missed,
        (unsigned long)stats.driver_rx_overrun, (unsigned long)stats.bus_errors,
        (unsigned long)stats.arb_lost, (unsigned long)stats.tx_error_counter,
        (unsigned long)stats.rx_error_counter, (double)rateHz, stateStr);
}
