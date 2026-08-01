import XCTest
@testable import PulseBoardShared

final class ElapsedTimeFormatterTests: XCTestCase {
    func testUnderAnHour() {
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 75), "1:15")
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 9), "0:09")
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 0), "0:00")
    }

    func testAtOrOverAnHour() {
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 3661), "1:01:01")
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 3600), "1:00:00")
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 7325), "2:02:05")
    }

    func testNegativeClampsToZero() {
        XCTAssertEqual(ElapsedTimeFormatter.string(from: -5), "0:00")
    }
}

final class CalorieFormatterTests: XCTestCase {
    func testRoundsToNearestWholeCalorie() {
        XCTAssertEqual(CalorieFormatter.string(fromKilocalories: 214.6), "215 cal")
        XCTAssertEqual(CalorieFormatter.string(fromKilocalories: 214.4), "214 cal")
        XCTAssertEqual(CalorieFormatter.string(fromKilocalories: 0), "0 cal")
    }
}

final class DistanceFormatterTests: XCTestCase {
    func testMetricUnderAndOverAKilometer() {
        XCTAssertEqual(DistanceFormatter.string(fromMeters: 1830, usesMetric: true), "1.83 km")
        XCTAssertEqual(DistanceFormatter.string(fromMeters: 500, usesMetric: true), "500 m")
    }

    func testImperialConvertsMetersToMiles() {
        XCTAssertEqual(DistanceFormatter.string(fromMeters: 1609.344, usesMetric: false), "1.00 mi")
    }
}
