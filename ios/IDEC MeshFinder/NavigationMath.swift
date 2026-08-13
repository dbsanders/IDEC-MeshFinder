import Foundation

struct GeoPoint: Equatable {
    let latitude: Double
    let longitude: Double
    let altitudeM: Double?

    init(latitude: Double, longitude: Double, altitudeM: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeM = altitudeM
    }
}

struct AimSolution: Equatable {
    let distanceM: Double
    let bearingToSiteDeg: Double
    let elevationAngleDeg: Double
    let sectorBearingFromSiteDeg: Double
    let sectorOffsetDeg: Double
    let nominalEdgeDeltaDeg: Double
    let horizontalCorrectionDeg: Double?
    let verticalCorrectionDeg: Double?

    var sectorPhrase: String {
        let absoluteOffset = abs(sectorOffsetDeg)
        if nominalEdgeDeltaDeg >= 20 {
            return absoluteOffset <= 20 ? "Near sector center" : "Good sector position"
        }
        if nominalEdgeDeltaDeg >= 0 {
            return "Near nominal edge"
        }
        return "Beyond nominal beamwidth"
    }

    var nominalEdgeDescription: String {
        let rounded = Int(abs(nominalEdgeDeltaDeg).rounded())
        if nominalEdgeDeltaDeg >= 0 {
            return "\(rounded) degrees inside nominal sector edge"
        }
        return "\(rounded) degrees beyond nominal sector edge"
    }
}

struct ReachabilityScore: Equatable, Comparable {
    let distanceM: Double
    let sectorOffsetDeg: Double
    let nominalEdgeDeltaDeg: Double
    let radio: MeshRadio

    var sectorPhrase: String {
        let absoluteOffset = abs(sectorOffsetDeg)
        if nominalEdgeDeltaDeg >= 20 {
            return absoluteOffset <= 20 ? "Near sector center" : "Good sector position"
        }
        if nominalEdgeDeltaDeg >= 0 {
            return "Near nominal edge"
        }
        return "Beyond nominal beamwidth"
    }

    static func < (lhs: ReachabilityScore, rhs: ReachabilityScore) -> Bool {
        if lhs.nominalEdgeDeltaDeg >= 0, rhs.nominalEdgeDeltaDeg < 0 {
            return true
        }
        if lhs.nominalEdgeDeltaDeg < 0, rhs.nominalEdgeDeltaDeg >= 0 {
            return false
        }

        let lhsOffset = abs(lhs.sectorOffsetDeg)
        let rhsOffset = abs(rhs.sectorOffsetDeg)
        if abs(lhsOffset - rhsOffset) > 5 {
            return lhsOffset < rhsOffset
        }

        return lhs.distanceM < rhs.distanceM
    }
}

enum NavigationMath {
    private static let earthRadiusM = 6_371_000.0

    static func distanceMeters(from start: GeoPoint, to end: GeoPoint) -> Double {
        let startLatitude = radians(start.latitude)
        let endLatitude = radians(end.latitude)
        let latitudeDelta = radians(end.latitude - start.latitude)
        let longitudeDelta = radians(end.longitude - start.longitude)

        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(startLatitude) * cos(endLatitude)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusM * c
    }

    static func trueBearingDegrees(from start: GeoPoint, to end: GeoPoint) -> Double {
        let startLatitude = radians(start.latitude)
        let endLatitude = radians(end.latitude)
        let longitudeDelta = radians(end.longitude - start.longitude)
        let y = sin(longitudeDelta) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude)
            - sin(startLatitude) * cos(endLatitude) * cos(longitudeDelta)
        return normalizedDegrees(degrees(atan2(y, x)))
    }

    static func elevationAngleDegrees(user: GeoPoint, site: MeshSite, antenna: MeshAntenna) -> Double {
        let horizontalDistance = max(distanceMeters(from: user, to: site.point), 1)
        let userAltitude = user.altitudeM ?? 0
        let antennaAltitude = site.elevationM + antenna.heightAGLM
        return degrees(atan2(antennaAltitude - userAltitude, horizontalDistance))
    }

    static func signedAngularDifferenceDegrees(from current: Double, to target: Double) -> Double {
        var difference = normalizedDegrees(target) - normalizedDegrees(current)
        if difference > 180 {
            difference -= 360
        }
        if difference < -180 {
            difference += 360
        }
        return difference
    }

    static func sectorOffsetDegrees(centerAzimuth: Double, bearingFromSite: Double) -> Double {
        signedAngularDifferenceDegrees(from: centerAzimuth, to: bearingFromSite)
    }

    static func solution(
        user: GeoPoint,
        site: MeshSite,
        radio: MeshRadio,
        currentHeadingDeg: Double?,
        currentPitchDeg: Double?
    ) -> AimSolution {
        let distance = distanceMeters(from: user, to: site.point)
        let bearingToSite = trueBearingDegrees(from: user, to: site.point)
        let sectorBearing = trueBearingDegrees(from: site.point, to: user)
        let elevation = elevationAngleDegrees(user: user, site: site, antenna: radio.antenna)
        let offset = sectorOffsetDegrees(
            centerAzimuth: radio.antenna.centerAzimuthDeg,
            bearingFromSite: sectorBearing
        )
        let edgeDelta = radio.antenna.beamwidthDeg / 2 - abs(offset)

        return AimSolution(
            distanceM: distance,
            bearingToSiteDeg: bearingToSite,
            elevationAngleDeg: elevation,
            sectorBearingFromSiteDeg: sectorBearing,
            sectorOffsetDeg: offset,
            nominalEdgeDeltaDeg: edgeDelta,
            horizontalCorrectionDeg: currentHeadingDeg.map {
                signedAngularDifferenceDegrees(from: $0, to: bearingToSite)
            },
            verticalCorrectionDeg: currentPitchDeg.map {
                elevation - $0
            }
        )
    }

    static func reachabilityScore(user: GeoPoint, site: MeshSite, radio: MeshRadio) -> ReachabilityScore {
        let distance = distanceMeters(from: user, to: site.point)
        let sectorBearing = trueBearingDegrees(from: site.point, to: user)
        let offset = sectorOffsetDegrees(
            centerAzimuth: radio.antenna.centerAzimuthDeg,
            bearingFromSite: sectorBearing
        )
        let edgeDelta = radio.antenna.beamwidthDeg / 2 - abs(offset)
        return ReachabilityScore(
            distanceM: distance,
            sectorOffsetDeg: offset,
            nominalEdgeDeltaDeg: edgeDelta,
            radio: radio
        )
    }

    static func bestReachabilityScore(user: GeoPoint, site: MeshSite) -> ReachabilityScore? {
        site.radios
            .map { reachabilityScore(user: user, site: site, radio: $0) }
            .min()
    }

    static func normalizedDegrees(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }

    private static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func degrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}

extension MeshSite {
    var point: GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude, altitudeM: elevationM)
    }
}
