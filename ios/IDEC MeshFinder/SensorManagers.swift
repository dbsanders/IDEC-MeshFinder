import CoreLocation
import CoreMotion
import Foundation

@Observable
final class LocationHeadingManager: NSObject, CLLocationManagerDelegate {
    var location: GeoPoint?
    var horizontalAccuracyM: Double?
    var altitudeAccuracyM: Double?
    var trueHeadingDeg: Double?
    var magneticHeadingDeg: Double?
    var headingAccuracyDeg: Double?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var locationError: String?

    private let manager = CLLocationManager()
    private var hasRequestedStart = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
        manager.headingFilter = 1
        authorizationStatus = manager.authorizationStatus
    }

    func start() {
        hasRequestedStart = true
        handleAuthorizationStatus(manager.authorizationStatus)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        guard hasRequestedStart else { return }
        handleAuthorizationStatus(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        location = GeoPoint(
            latitude: latest.coordinate.latitude,
            longitude: latest.coordinate.longitude,
            altitudeM: latest.verticalAccuracy >= 0 ? latest.altitude : nil
        )
        horizontalAccuracyM = latest.horizontalAccuracy >= 0 ? latest.horizontalAccuracy : nil
        altitudeAccuracyM = latest.verticalAccuracy >= 0 ? latest.verticalAccuracy : nil
        locationError = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        trueHeadingDeg = newHeading.trueHeading >= 0 ? newHeading.trueHeading : nil
        magneticHeadingDeg = newHeading.magneticHeading >= 0 ? newHeading.magneticHeading : nil
        headingAccuracyDeg = newHeading.headingAccuracy >= 0 ? newHeading.headingAccuracy : nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        locationError = error.localizedDescription
    }

    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationError = nil
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        case .denied:
            locationError = "Location access is denied. Enable While Using the App in Settings to calculate live aiming guidance."
        case .restricted:
            locationError = "Location access is restricted on this device."
        @unknown default:
            locationError = "Location authorization is unavailable."
        }
    }
}

@Observable
final class MotionPitchManager {
    var pitchDeg: Double?
    var isAvailable = false

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    init() {
        queue.name = "IDECMeshFinder.Motion"
        isAvailable = manager.isDeviceMotionAvailable
    }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else {
            return
        }
        manager.deviceMotionUpdateInterval = 1.0 / 20.0
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let motion else { return }
            let pitch = Self.aimElevationDegrees(gravityZ: motion.gravity.z)
            Task { @MainActor in
                self?.pitchDeg = pitch
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    static func aimElevationDegrees(gravityZ: Double) -> Double {
        let clampedZ = min(1, max(-1, gravityZ))
        return asin(-clampedZ) * 180 / .pi
    }
}
