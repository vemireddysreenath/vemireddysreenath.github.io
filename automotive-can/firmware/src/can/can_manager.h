#pragma once

#include <cstdint>
#include "can_frame.h"
#include "driver/twai.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"

// Snapshot of receive-side health counters. The tx_* counters are expected
// to stay at 0 forever: MVP1 never calls twai_transmit() anywhere, and the
// driver is installed in TWAI_MODE_LISTEN_ONLY, so the controller physically
// cannot drive the bus. See ../../README.md "How to verify no CAN
// transmission is occurring".
struct CanStats {
    uint32_t rx_frames = 0;         // frames successfully queued to the app ring buffer
    uint32_t ring_dropped = 0;      // frames lost because the app ring buffer was full (consumer too slow)
    uint32_t driver_rx_missed = 0;  // twai_status_info_t.rx_missed_count (driver RX queue was full)
    uint32_t driver_rx_overrun = 0; // twai_status_info_t.rx_overrun_count (hardware RX FIFO overrun)
    uint32_t bus_errors = 0;        // twai_status_info_t.bus_error_count
    uint32_t arb_lost = 0;          // twai_status_info_t.arb_lost_count (should be 0: listen-only never arbitrates)
    uint32_t tx_error_counter = 0;  // twai_status_info_t.tx_error_counter (must stay 0)
    uint32_t rx_error_counter = 0;  // twai_status_info_t.rx_error_counter
    twai_state_t state = TWAI_STATE_STOPPED;
};

class CanManager {
public:
    // Installs and starts the TWAI driver in listen-only mode at the
    // bitrate configured in can_config.h, with an accept-all filter.
    // Call once from setup().
    bool begin();

    // Runs forever: blocks on the TWAI driver's internal RX queue and
    // pushes each frame into our own software ring buffer. Meant to run in
    // its own FreeRTOS task (see main.cpp) so CAN reception never depends
    // on how fast something else (USB) drains frames back out.
    void rxTaskLoop();

    // Pops one frame from the software ring buffer, if available.
    // timeout_ms = 0 means "don't block, return false immediately if empty".
    bool receive(CanFrame& frame, uint32_t timeout_ms = 0);

    // Reads twai_get_status_info() and merges it with our own
    // rx_frames/ring_dropped counters into one snapshot.
    CanStats getStats();

private:
    QueueHandle_t ringBuffer_ = nullptr;
    volatile uint32_t rxFrames_ = 0;
    volatile uint32_t ringDropped_ = 0;
};
