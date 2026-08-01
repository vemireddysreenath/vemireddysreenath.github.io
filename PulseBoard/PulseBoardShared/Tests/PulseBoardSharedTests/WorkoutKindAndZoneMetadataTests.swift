import XCTest
@testable import PulseBoardShared

final class WorkoutKindTests: XCTestCase {
    func testEveryCaseHasDisplayNameAndSymbol() {
        for kind in WorkoutKind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty)
            XCTAssertFalse(kind.symbolName.isEmpty)
        }
    }

    func testTracksDistanceOnlyForRunningWalkingCycling() {
        let distanceKinds: Set<WorkoutKind> = [.running, .walking, .cycling]
        for kind in WorkoutKind.allCases {
            XCTAssertEqual(kind.tracksDistance, distanceKinds.contains(kind), "\(kind) distance tracking mismatch")
        }
    }

    func testRawValuesAreStableForPersistence() {
        // These are Codable and cached to disk/HealthKit metadata — changing
        // a raw value would silently corrupt saved history, so pin them.
        XCTAssertEqual(WorkoutKind.strength.rawValue, "strength")
        XCTAssertEqual(WorkoutKind.running.rawValue, "running")
        XCTAssertEqual(WorkoutKind.walking.rawValue, "walking")
        XCTAssertEqual(WorkoutKind.cycling.rawValue, "cycling")
        XCTAssertEqual(WorkoutKind.hiit.rawValue, "hiit")
        XCTAssertEqual(WorkoutKind.yoga.rawValue, "yoga")
        XCTAssertEqual(WorkoutKind.other.rawValue, "other")
    }
}

final class HeartRateZoneTests: XCTestCase {
    func testEveryZoneHasDisplayName() {
        for zone in HeartRateZone.allCases {
            XCTAssertFalse(zone.displayName.isEmpty)
        }
    }

    func testZonesSortAscendingByIntensity() {
        XCTAssertEqual(HeartRateZone.allCases.sorted(), [.zone1, .zone2, .zone3, .zone4, .zone5])
        XCTAssertTrue(HeartRateZone.zone1 < HeartRateZone.zone5)
    }
}
