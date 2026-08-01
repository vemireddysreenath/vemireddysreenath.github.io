import XCTest
@testable import PulseBoardShared

final class HRZoneCalculatorTests: XCTestCase {

    func testEstimatedMaxHR() {
        XCTAssertEqual(HRZoneCalculator.estimatedMaxHR(age: 30), 190)
        XCTAssertEqual(HRZoneCalculator.estimatedMaxHR(age: 0), 220)
    }

    func testEstimatedMaxHRNeverNegative() {
        XCTAssertEqual(HRZoneCalculator.estimatedMaxHR(age: 250), 0)
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testMaxHRFromDateOfBirthAfterBirthdayThisYear() {
        let calendar = utcCalendar()
        let dob = calendar.date(from: DateComponents(year: 1994, month: 6, day: 15))!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        XCTAssertEqual(HRZoneCalculator.maxHR(dateOfBirth: dob, referenceDate: reference, calendar: calendar), 220 - 32)
    }

    func testMaxHRFromDateOfBirthBeforeBirthdayThisYear() {
        let calendar = utcCalendar()
        let dob = calendar.date(from: DateComponents(year: 1994, month: 12, day: 15))!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        XCTAssertEqual(HRZoneCalculator.maxHR(dateOfBirth: dob, referenceDate: reference, calendar: calendar), 220 - 31)
    }

    func testZoneBoundariesAtExactCutPoints() {
        let maxHR = 200.0
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 90, maxHR: maxHR), .zone1)   // 45%
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 100, maxHR: maxHR), .zone1)  // exactly 50%
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 119, maxHR: maxHR), .zone1)  // 59.5%
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 120, maxHR: maxHR), .zone2)  // exactly 60%
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 140, maxHR: maxHR), .zone3)  // exactly 70%
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 160, maxHR: maxHR), .zone4)  // exactly 80%
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 180, maxHR: maxHR), .zone5)  // exactly 90%
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 220, maxHR: maxHR), .zone5)  // 110%, clamps at top
    }

    func testZoneDegenerateInputsNeverCrashAndClampToZone1() {
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 150, maxHR: 0), .zone1)
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 0, maxHR: 190), .zone1)
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: -10, maxHR: 190), .zone1)
        XCTAssertEqual(HRZoneCalculator.zone(forHeartRate: 150, maxHR: -50), .zone1)
    }

    func testZoneRangesCoverAllFiveZonesAscendingWithOpenTopEnd() {
        let ranges = HRZoneCalculator.zoneRanges(maxHR: 200)
        XCTAssertEqual(ranges.count, 5)
        XCTAssertEqual(ranges.map(\.zone), HeartRateZone.allCases.sorted())
        XCTAssertEqual(ranges[0].lowerBPM, 100)
        XCTAssertEqual(ranges[0].upperBPM, 119)
        XCTAssertEqual(ranges[1].lowerBPM, 120)
        XCTAssertEqual(ranges[3].upperBPM, 179)
        XCTAssertEqual(ranges[4].lowerBPM, 180)
        XCTAssertNil(ranges[4].upperBPM)
    }
}
