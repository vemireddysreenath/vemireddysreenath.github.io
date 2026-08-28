#pragma once

#include "transport.h"
#include "../can/can_manager.h"

// USB-serial transport: writes CSV frame lines and human-readable status
// lines to Serial (USB CDC). MVP1's only transport.
class USBTransport : public FrameTransport {
public:
    explicit USBTransport(unsigned long baud = 115200) : baud_(baud) {}

    bool begin() override;
    bool sendFrame(const CanFrame& frame) override;

    // Not part of FrameTransport -- BLE/Wi-Fi transports won't share this
    // text format. main.cpp calls these directly.
    void printBanner();
    void printStats(const CanStats& stats, float rateHz);

private:
    unsigned long baud_;
};
