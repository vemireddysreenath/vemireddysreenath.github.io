import XCTest
@testable import PulseBoardShared

final class WorkoutSummaryCodingTests: XCTestCase {

    func testDurationIsEndMinusStart() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 1_925)
        let summary = WorkoutSummary(
            workoutKind: .hiit,
            startDate: start,
            endDate: end,
            avgHR: 140,
            minHR: 95,
            maxHR: 175,
            activeCalories: 300,
            totalCalories: 420,
            distanceMeters: nil,
            zoneDistribution: []
        )
        XCTAssertEqual(summary.duration, 925, accuracy: 0.0001)
    }

    func testRoundTripWithFullZoneDistribution() throws {
        var accumulator = ZoneTimeAccumulator()
        let start = Date(timeIntervalSince1970: 500_000)
        accumulator.record(heartRate: 100, at: start, maxHR: 200)
        accumulator.record(heartRate: 140, at: start.addingTimeInterval(60), maxHR: 200)
        accumulator.record(heartRate: 185, at: start.addingTimeInterval(600), maxHR: 200)

        let summary = WorkoutSummary(
            workoutKind: .running,
            startDate: start,
            endDate: start.addingTimeInterval(600),
            avgHR: 138.4,
            minHR: 92,
            maxHR: 188,
            activeCalories: 410.2,
            totalCalories: 520.9,
            distanceMeters: 5230.8,
            zoneDistribution: accumulator.asZoneDurations
        )

        let data = try JSONEncoder.pulseBoard.encode(summary)
        let decoded = try JSONDecoder.pulseBoard.decode(WorkoutSummary.self, from: data)

        XCTAssertEqual(decoded, summary)
        XCTAssertEqual(decoded.zoneDistribution.count, 5)
        XCTAssertEqual(decoded.zoneDistribution.map(\.zone), HeartRateZone.allCases.sorted())
    }

    func testRoundTripWithNilOptionalFields() throws {
        let summary = WorkoutSummary(
            workoutKind: .yoga,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 1800),
            avgHR: nil,
            minHR: nil,
            maxHR: nil,
            activeCalories: 120,
            totalCalories: 180,
            distanceMeters: nil,
            zoneDistribution: []
        )
        let data = try JSONEncoder.pulseBoard.encode(summary)
        let decoded = try JSONDecoder.pulseBoard.decode(WorkoutSummary.self, from: data)
        XCTAssertEqual(decoded, summary)
    }

    func testIdentityIsPreservedAcrossRoundTrip() throws {
        let summary = WorkoutSummary(
            id: UUID(),
            workoutKind: .cycling,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 100),
            avgHR: 130,
            minHR: 100,
            maxHR: 160,
            activeCalories: 90,
            totalCalories: 120,
            distanceMeters: 4200,
            zoneDistribution: []
        )
        let data = try JSONEncoder.pulseBoard.encode(summary)
        let decoded = try JSONDecoder.pulseBoard.decode(WorkoutSummary.self, from: data)
        XCTAssertEqual(decoded.id, summary.id)
    }

    func testWCSessionPayloadRoundTrip() throws {
        var accumulator = ZoneTimeAccumulator()
        let start = Date(timeIntervalSince1970: 200_000)
        accumulator.record(heartRate: 110, at: start, maxHR: 190)
        accumulator.record(heartRate: 150, at: start.addingTimeInterval(300), maxHR: 190)

        let summary = WorkoutSummary(
            workoutKind: .strength,
            startDate: start,
            endDate: start.addingTimeInterval(300),
            avgHR: 128,
            minHR: 105,
            maxHR: 158,
            activeCalories: 180,
            totalCalories: 210,
            distanceMeters: nil,
            zoneDistribution: accumulator.asZoneDurations
        )

        let payload = try summary.wcSessionPayload()
        XCTAssertTrue(payload[WorkoutSummary.connectivityKey] is Data)
        let decoded = try WorkoutSummary.decode(fromWCSessionPayload: payload)
        XCTAssertEqual(decoded, summary)
    }

    func testWCSessionPayloadMissingKeyThrows() {
        XCTAssertThrowsError(try WorkoutSummary.decode(fromWCSessionPayload: [:])) { error in
            XCTAssertEqual(error as? ConnectivityPayloadError, .missingPayload)
        }
    }
}
