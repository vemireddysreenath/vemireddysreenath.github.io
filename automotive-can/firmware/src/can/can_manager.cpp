#include "can_manager.h"

#include <cstring>
#include "can_config.h"
#include "esp_timer.h"

bool CanManager::begin() {
    ringBuffer_ = xQueueCreate(CanConfig::SW_RING_BUFFER_LEN, sizeof(CanFrame));
    if (ringBuffer_ == nullptr) {
        return false;
    }

    // TWAI_MODE_LISTEN_ONLY is the MVP1 safety invariant: the driver
    // acknowledges nothing and cannot transmit, enforced by the ESP32-S3
    // TWAI peripheral itself, not just by us never calling twai_transmit().
    twai_general_config_t g_config =
        TWAI_GENERAL_CONFIG_DEFAULT(CanConfig::TX_GPIO, CanConfig::RX_GPIO, TWAI_MODE_LISTEN_ONLY);
    g_config.rx_queue_len = CanConfig::DRIVER_RX_QUEUE_LEN;

    twai_timing_config_t t_config = CanConfig::timingConfig();
    twai_filter_config_t f_config = TWAI_FILTER_CONFIG_ACCEPT_ALL();

    if (twai_driver_install(&g_config, &t_config, &f_config) != ESP_OK) {
        return false;
    }
    if (g_config.mode != TWAI_MODE_LISTEN_ONLY) {
        return false;  // should be unreachable; fail closed if it ever isn't
    }
    if (twai_start() != ESP_OK) {
        return false;
    }

    return true;
}

void CanManager::rxTaskLoop() {
    twai_message_t msg;
    for (;;) {
        // Block up to 100ms on the driver's own RX queue. This is a real
        // FreeRTOS block (not a busy-wait), so it costs nothing when the
        // bus is idle.
        esp_err_t err = twai_receive(&msg, pdMS_TO_TICKS(100));
        if (err != ESP_OK) {
            continue;  // timeout or transient error; loop and try again
        }

        CanFrame frame{};
        frame.timestamp_us = static_cast<uint64_t>(esp_timer_get_time());
        frame.can_id = msg.identifier;
        frame.dlc = msg.data_length_code;
        frame.flags = 0;
        if (msg.extd) frame.flags |= CAN_FLAG_EXTENDED;
        if (msg.rtr) frame.flags |= CAN_FLAG_RTR;
        memcpy(frame.data, msg.data, sizeof(frame.data));

        if (xQueueSend(ringBuffer_, &frame, 0) == pdTRUE) {
            rxFrames_++;
        } else {
            ringDropped_++;  // software ring buffer full: consumer (USB) is behind
        }
    }
}

bool CanManager::receive(CanFrame& frame, uint32_t timeout_ms) {
    if (ringBuffer_ == nullptr) return false;
    return xQueueReceive(ringBuffer_, &frame, pdMS_TO_TICKS(timeout_ms)) == pdTRUE;
}

CanStats CanManager::getStats() {
    CanStats stats;
    stats.rx_frames = rxFrames_;
    stats.ring_dropped = ringDropped_;

    twai_status_info_t info;
    if (twai_get_status_info(&info) == ESP_OK) {
        stats.driver_rx_missed = info.rx_missed_count;
        stats.driver_rx_overrun = info.rx_overrun_count;
        stats.bus_errors = info.bus_error_count;
        stats.arb_lost = info.arb_lost_count;
        stats.tx_error_counter = info.tx_error_counter;
        stats.rx_error_counter = info.rx_error_counter;
        stats.state = info.state;
    }
    return stats;
}
