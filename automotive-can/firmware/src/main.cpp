// MVP1 -- raw CAN reception only.
//
//   CAR -> OBD-II -> SN65HVD230 -> ESP32-S3 -> USB -> Mac
//
// TWAI is initialized in listen-only mode (CAN RX = YES, CAN TX = NO).
// This file never calls twai_transmit(); see can/can_manager.cpp for the
// listen-only enforcement. See ../README.md for wiring, build/flash/
// monitor commands, and how to verify no transmission is occurring.

#include <Arduino.h>
#include "can/can_config.h"
#include "can/can_manager.h"
#include "transport/usb_transport.h"

static CanManager canManager;
static USBTransport usbTransport;

static void canRxTask(void* /*pvParameters*/) {
    canManager.rxTaskLoop();  // never returns
}

void setup() {
    usbTransport.begin();
    usbTransport.printBanner();

    if (!canManager.begin()) {
        Serial.println("# FATAL: TWAI driver init failed (no CAN activity, no transmission)");
        while (true) {
            delay(1000);
        }
    }
    Serial.println("# TWAI driver started (listen-only, accept-all filter)");

    // Dedicated, higher-priority task drains the TWAI driver's RX queue
    // into our own larger software ring buffer, so CAN reception never
    // depends on how fast Serial/USB can keep up (see CanManager::rxTaskLoop).
    xTaskCreatePinnedToCore(canRxTask, "canRx", 4096, nullptr,
                             configMAX_PRIORITIES - 2, nullptr, 1);
}

void loop() {
    static uint32_t lastStatsMs = 0;
    static uint32_t lastRxFrames = 0;

    CanFrame frame;
    while (canManager.receive(frame, 0)) {
        usbTransport.sendFrame(frame);
    }

    uint32_t now = millis();
    if (now - lastStatsMs >= 1000) {
        CanStats stats = canManager.getStats();
        float elapsedS = (now - lastStatsMs) / 1000.0f;
        float rateHz = (stats.rx_frames - lastRxFrames) / elapsedS;
        usbTransport.printStats(stats, rateHz);
        lastRxFrames = stats.rx_frames;
        lastStatsMs = now;
    }
}
