import Foundation
import Testing
@testable import IDEC_MeshFinder

struct IDEC_MeshFinderTests {

    @Test func validatesBundledDatasetShape() throws {
        let dataset = try MeshRepository().decode(Self.bundledData())

        #expect(dataset.schemaVersion == 1)
        #expect(dataset.sites.count == 4)
        #expect(dataset.sites.first { $0.id == "signal-peak" }?.radios.count == 2)
    }

    @Test func rejectsUnsupportedSchemaVersion() throws {
        let invalidJSON = try Self.bundledJSON().replacingOccurrences(of: "\"schema_version\": 1", with: "\"schema_version\": 99")

        #expect(throws: MeshDataError.unsupportedSchemaVersion(99)) {
            _ = try MeshRepository().decode(Data(invalidJSON.utf8))
        }
    }

    @Test func rejectsDuplicateSiteIDs() throws {
        let bundledJSON = try Self.bundledJSON()
        let range = try #require(bundledJSON.range(of: "\"id\": \"signal-peak\""))
        let invalidJSON = bundledJSON.replacingCharacters(in: range, with: "\"id\": \"tomato-springs\"")

        #expect(throws: MeshDataError.duplicateSiteID("tomato-springs")) {
            _ = try MeshRepository().decode(Data(invalidJSON.utf8))
        }
    }

    @Test func rejectsOlderRefreshDataset() throws {
        let current = try MeshRepository().decode(Self.bundledData())
        let olderJSON = try Self.bundledJSON().replacingOccurrences(of: "\"dataset_version\": 1", with: "\"dataset_version\": 0")

        #expect(throws: MeshDataError.olderDataset(newVersion: 0, currentVersion: 1)) {
            _ = try MeshRepository().decode(Data(olderJSON.utf8), currentDataset: current)
        }
    }

    @Test func refreshRequestBypassesLocalCache() throws {
        let source = try #require(URL(string: "https://example.com/nodes.json"))
        let request = MeshRepository().refreshRequest(for: source)

        #expect(request.url == source)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.timeoutInterval == 12)
    }

    @Test func angularDifferenceHandlesNorthWraparound() {
        #expect(NavigationMath.signedAngularDifferenceDegrees(from: 350, to: 10) == 20)
        #expect(NavigationMath.signedAngularDifferenceDegrees(from: 10, to: 350) == -20)
        #expect(NavigationMath.sectorOffsetDegrees(centerAzimuth: 350, bearingFromSite: 10) == 20)
    }

    @Test func motionAimElevationUsesScreenNormalAngle() {
        #expect(MotionPitchManager.aimElevationDegrees(gravityZ: -1) == -90)
        #expect(MotionPitchManager.aimElevationDegrees(gravityZ: 0) == 0)
        #expect(MotionPitchManager.aimElevationDegrees(gravityZ: 1) == 90)
    }

    @Test func computesKnownIrvineNavigationValues() throws {
        let dataset = try MeshRepository().decode(Self.bundledData())
        let cityHall = #require(dataset.sites.first { $0.id == "city-hall" })
        let signalPeak = #require(dataset.sites.first { $0.id == "signal-peak" })
        let radio = #require(signalPeak.radios.first)
        let solution = NavigationMath.solution(
            user: cityHall.point,
            site: signalPeak,
            radio: radio,
            currentHeadingDeg: 210,
            currentPitchDeg: 0
        )

        #expect(solution.distanceM > 10_000)
        #expect(solution.distanceM < 12_000)
        #expect(solution.bearingToSiteDeg > 200)
        #expect(solution.bearingToSiteDeg < 230)
        #expect(solution.horizontalCorrectionDeg != nil)
        #expect(solution.elevationAngleDeg > 0)
    }

    @Test func reachabilitySortPrioritizesSectorPositionBeforeDistance() {
        let user = GeoPoint(latitude: 0, longitude: 0)
        let nearOutside = Self.site(
            id: "near-outside",
            latitude: 0,
            longitude: 0.01,
            azimuth: 90
        )
        let fartherInside = Self.site(
            id: "farther-inside",
            latitude: 0.02,
            longitude: 0,
            azimuth: 180
        )

        let nearScore = #require(NavigationMath.bestReachabilityScore(user: user, site: nearOutside))
        let farScore = #require(NavigationMath.bestReachabilityScore(user: user, site: fartherInside))

        #expect(nearScore.nominalEdgeDeltaDeg < 0)
        #expect(farScore.nominalEdgeDeltaDeg >= 0)
        #expect(farScore < nearScore)
    }

    private static func bundledData() throws -> Data {
        let url = #require(Bundle.main.url(forResource: "nodes", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private static func bundledJSON() throws -> String {
        String(decoding: try bundledData(), as: UTF8.self)
    }

    private static func site(id: String, latitude: Double, longitude: Double, azimuth: Double) -> MeshSite {
        MeshSite(
            id: id,
            name: id,
            latitude: latitude,
            longitude: longitude,
            elevationM: 0,
            radios: [
                MeshRadio(
                    arednName: "\(id)-radio",
                    bandGHz: 5,
                    channel: 170,
                    bandwidthMHz: 10,
                    mode: .mesh,
                    hardware: "Test",
                    antenna: MeshAntenna(
                        manufacturer: "Test",
                        model: "Test",
                        type: "sector",
                        gainDbi: 19,
                        beamwidthDeg: 120,
                        centerAzimuthDeg: azimuth,
                        electricalDowntiltDeg: 0,
                        heightAGLM: 10,
                        orientationAccuracyDeg: nil
                    )
                )
            ]
        )
    }
}
