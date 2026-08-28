#pragma once

#include "../can/can_frame.h"

// Common interface for anything that moves raw CanFrames off the ESP32:
// USB now, BLE/Wi-Fi in later MVPs. CanManager and main.cpp only ever talk
// to a FrameTransport through this interface, so the CAN driver never
// contains transport-specific logic and adding BLE/Wi-Fi later never
// requires touching can/.
class FrameTransport {
public:
    virtual ~FrameTransport() = default;
    virtual bool begin() = 0;
    virtual bool sendFrame(const CanFrame& frame) = 0;
};
