import XCTest
@testable import PulseBoardShared

final class MetricPacketCodingTests: XCTestCase {

    private func samplePacket() -> MetricPacket {
        MetricPacket(
            timestamp: Date(timeIntervalSince1970: 1_754_000_000),
            heartRate: 142.5,
            hrMin: 98,
            hrMax: 168,
            hrAvg: 133.2,
            activeCalories: 214.7,
            totalCalories: 340.1,
            elapsed: 725,
            distanceMeters: 1830.4,
            workoutKind: .running,
            phase: .running
        )
    }

    func testJSONRoundTrip() throws {
        let packet = samplePacket()
        let data = try JSONEncoder.pulseBoard.encode(packet)
        let decoded = try JSONDecoder.pulseBoard.decode(MetricPacket.self, from: data)
        XCTAssertEqual(decoded, packet)
    }

    func testJSONRoundTripWithNilOptionals() throws {
        let packet = MetricPacket(
            timestamp: Date(timeIntervalSince1970: 0),
            heartRate: nil,
            hrMin: nil,
            hrMax: nil,
            hrAvg: nil,
            activeCalories: 0,
            totalCalories: 0,
            elapsed: 0,
            distanceMeters: nil,
            workoutKind: .strength,
            phase: .paused
        )
        let data = try JSONEncoder.pulseBoard.encode(packet)
        let decoded = try JSONDecoder.pulseBoard.decode(MetricPacket.self, from: data)
        XCTAssertEqual(decoded, packet)
    }

    func testWCSessionPayloadRoundTrip() throws {
        let packet = samplePacket()
        let payload = try packet.wcSessionPayload()
        XCTAssertTrue(payload[MetricPacket.connectivityKey] is Data)
        let decoded = try MetricPacket.decode(fromWCSessionPayload: payload)
        XCTAssertEqual(decoded, packet)
    }

    func testWCSessionPayloadMissingKeyThrowsMissingPayload() {
        XCTAssertThrowsError(try MetricPacket.decode(fromWCSessionPayload: [:])) { error in
            XCTAssertEqual(error as? ConnectivityPayloadError, .missingPayload)
        }
    }

    func testWCSessionPayloadWrongTypeThrowsMissingPayload() {
        XCTAssertThrowsError(
            try MetricPacket.decode(fromWCSessionPayload: [MetricPacket.connectivityKey: "not data"])
        ) { error in
            XCTAssertEqual(error as? ConnectivityPayloadError, .missingPayload)
        }
    }

    func testAllWorkoutKindsAndPhasesRoundTrip() throws {
        for kind in WorkoutKind.allCases {
            for phase: WorkoutSessionPhase in [.running, .paused, .ended] {
                var packet = samplePacket()
                packet.workoutKind = kind
                packet.phase = phase
                let data = try JSONEncoder.pulseBoard.encode(packet)
                let decoded = try JSONDecoder.pulseBoard.decode(MetricPacket.self, from: data)
                XCTAssertEqual(decoded, packet)
            }
        }
    }
}
