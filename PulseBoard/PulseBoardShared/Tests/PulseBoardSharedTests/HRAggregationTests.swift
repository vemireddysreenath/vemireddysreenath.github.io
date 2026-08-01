import XCTest
@testable import PulseBoardShared

final class HRRollingStatsTests: XCTestCase {

    func testEmptyStats() {
        let stats = HRRollingStats()
        XCTAssertNil(stats.min)
        XCTAssertNil(stats.max)
        XCTAssertNil(stats.average)
        XCTAssertEqual(stats.sampleCount, 0)
    }

    func testRecordsMinMaxAvg() {
        var stats = HRRollingStats()
        for hr in [120.0, 150.0, 100.0, 140.0] {
            stats.record(hr)
        }
        XCTAssertEqual(stats.min, 100)
        XCTAssertEqual(stats.max, 150)
        XCTAssertEqual(stats.sampleCount, 4)
        XCTAssertEqual(stats.average ?? 0, 127.5, accuracy: 0.0001)
    }

    func testIgnoresNonPositiveSamplesAsSensorNoise() {
        var stats = HRRollingStats()
        stats.record(0)
        stats.record(-5)
        stats.record(130)
        XCTAssertEqual(stats.sampleCount, 1)
        XCTAssertEqual(stats.min, 130)
        XCTAssertEqual(stats.max, 130)
    }
}

final class ZoneTimeAccumulatorTests: XCTestCase {

    func testDistributesTimeToTheZoneOfTheEarlierSample() {
        var accumulator = ZoneTimeAccumulator()
        let maxHR = 200.0
        let start = Date(timeIntervalSince1970: 0)

        accumulator.record(heartRate: 100, at: start, maxHR: maxHR)                          // zone1 (50%)
        accumulator.record(heartRate: 140, at: start.addingTimeInterval(10), maxHR: maxHR)    // zone3 (70%), attributes prior 10s to zone1
        accumulator.record(heartRate: 190, at: start.addingTimeInterval(30), maxHR: maxHR)    // zone5 (95%), attributes prior 20s to zone3

        XCTAssertEqual(accumulator.duration(in: .zone1), 10, accuracy: 0.0001)
        XCTAssertEqual(accumulator.duration(in: .zone3), 20, accuracy: 0.0001)
        XCTAssertEqual(accumulator.duration(in: .zone5), 0, accuracy: 0.0001) // no sample after it yet
        XCTAssertEqual(accumulator.totalDuration, 30, accuracy: 0.0001)
    }

    func testFirstSampleAloneAccumulatesNoDuration() {
        var accumulator = ZoneTimeAccumulator()
        accumulator.record(heartRate: 150, at: Date(timeIntervalSince1970: 0), maxHR: 200)
        XCTAssertEqual(accumulator.totalDuration, 0, accuracy: 0.0001)
    }

    func testAsZoneDurationsCoversAllFiveZonesInOrder() {
        var accumulator = ZoneTimeAccumulator()
        accumulator.record(heartRate: 100, at: Date(timeIntervalSince1970: 0), maxHR: 200)
        accumulator.record(heartRate: 100, at: Date(timeIntervalSince1970: 5), maxHR: 200)

        let durations = accumulator.asZoneDurations
        XCTAssertEqual(durations.map(\.zone), HeartRateZone.allCases.sorted())
        XCTAssertEqual(durations.first(where: { $0.zone == .zone1 })?.duration ?? -1, 5, accuracy: 0.0001)
        XCTAssertEqual(durations.first(where: { $0.zone == .zone5 })?.duration ?? -1, 0, accuracy: 0.0001)
    }

    func testZeroOrNegativeDeltaBetweenSamplesIsIgnored() {
        var accumulator = ZoneTimeAccumulator()
        let t = Date(timeIntervalSince1970: 100)
        accumulator.record(heartRate: 100, at: t, maxHR: 200)
        accumulator.record(heartRate: 140, at: t, maxHR: 200)                     // duplicate timestamp
        accumulator.record(heartRate: 140, at: t.addingTimeInterval(-5), maxHR: 200) // out of order
        XCTAssertEqual(accumulator.totalDuration, 0, accuracy: 0.0001)
    }
}
