import XCTest
@testable import PulseBoardShared

final class RecencyLabelFormatterTests: XCTestCase {

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testJustNow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let sample = now.addingTimeInterval(-10)
        XCTAssertEqual(RecencyLabelFormatter.label(for: sample, now: now, calendar: utc), "just now")
    }

    func testMinutesAgo() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let sample = now.addingTimeInterval(-60 * 12)
        XCTAssertEqual(RecencyLabelFormatter.label(for: sample, now: now, calendar: utc), "12 min ago")
    }

    func testHoursAgoSameCalendarDay() {
        let now = date(2026, 8, 1, 14)
        let sample = date(2026, 8, 1, 11)
        XCTAssertEqual(RecencyLabelFormatter.label(for: sample, now: now, calendar: utc), "3h ago")
    }

    func testLastNightForLatePriorDaySample() {
        let now = date(2026, 8, 1, 8)
        let sample = date(2026, 7, 31, 23)
        XCTAssertEqual(RecencyLabelFormatter.label(for: sample, now: now, calendar: utc), "last night")
    }

    func testYesterdayForDaytimePriorDaySample() {
        let now = date(2026, 8, 1, 8)
        let sample = date(2026, 7, 31, 14)
        XCTAssertEqual(RecencyLabelFormatter.label(for: sample, now: now, calendar: utc), "yesterday")
    }

    func testDaysAgoWithinAWeek() {
        let now = date(2026, 8, 5, 8)
        let sample = date(2026, 8, 1, 8)
        XCTAssertEqual(RecencyLabelFormatter.label(for: sample, now: now, calendar: utc), "4 days ago")
    }

    func testShortDateBeyondAWeek() {
        let now = date(2026, 8, 10, 8)
        let sample = date(2026, 7, 20, 8)
        XCTAssertEqual(
            RecencyLabelFormatter.label(for: sample, now: now, calendar: utc, locale: Locale(identifier: "en_US_POSIX")),
            "Jul 20"
        )
    }

    func testFutureDateNeverProducesNegativeAgo() {
        let now = date(2026, 8, 1, 8)
        let sample = date(2026, 8, 1, 9) // 1h in the future (clock skew)
        XCTAssertEqual(RecencyLabelFormatter.label(for: sample, now: now, calendar: utc), "just now")
    }

    func testRespiratorySampleDisplayLabelMatchesPRDExampleFormat() {
        let now = date(2026, 8, 1, 8)
        let sample = RespiratoryRateSample(breathsPerMinute: 14.4, date: date(2026, 7, 31, 23))
        XCTAssertEqual(sample.displayLabel(now: now, calendar: utc), "14 br/min · last night")
    }
}
