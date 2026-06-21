import Foundation
import CoreLocation
import CoreMotion

/// Owns the live sensor feeds (compass heading, GPS course-over-ground, and device heel) and
/// publishes smoothed values for the UI. Designed for the phone lying flat, screen up, with the
/// top of the phone pointing at the bow.
///
/// Note: heading, course, and motion are all unavailable in the iOS Simulator — run on a device.
@Observable
@MainActor
final class SensorManager: NSObject {

    // Published, smoothed sensor state.
    private(set) var headingMagnetic: Double = 0      // degrees, 0 = magnetic north
    private(set) var headingValid = false
    private(set) var courseOverGround: Double? = nil  // degrees, nil if not yet known
    private(set) var speed: Double = 0                // m/s, 0 if stationary/unknown
    private(set) var heelDegrees: Double = 0          // +right-down (port), -left-down (starboard)
    private(set) var authorizationDenied = false

    private let location = CLLocationManager()
    private let motion = CMMotionManager()

    // Low-pass smoothing factors (0 = frozen, 1 = no smoothing).
    private let headingSmoothing = 0.2
    private let heelSmoothing = 0.15

    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.headingFilter = 1            // degrees
        location.distanceFilter = kCLDistanceFilterNone
    }

    func start() {
        location.requestWhenInUseAuthorization()
        if CLLocationManager.headingAvailable() {
            location.startUpdatingHeading()
        }
        location.startUpdatingLocation()
        startMotion()
    }

    func stop() {
        location.stopUpdatingHeading()
        location.stopUpdatingLocation()
        motion.stopDeviceMotionUpdates()
    }

#if DEBUG
    /// Feeds realistic fake sensor values so the UI can be captured in the Simulator
    /// (where compass/GPS/motion are all dead). DEBUG-only — never compiled into a release
    /// build, so it can't ship. Toggled by long-pressing the "TACK MATH" title.
    func startDemo() {
        stop()                                  // ensure no real feeds are running
        headingMagnetic = 42                    // close-hauled on starboard
        headingValid = true
        heelDegrees = -14                       // left side low → starboard tack
        speed = 3.1                             // m/s ≈ 6.0 kn
        courseOverGround = 44                   // within tolerance of heading → no warning banner
        authorizationDenied = false
    }

    /// Demo-only: rotate the fake heading (e.g. from a drag). Keeps course aligned so the
    /// alignment warning banner stays hidden.
    func demoAdjustHeading(by deltaDegrees: Double) {
        headingMagnetic = Compass.normalize(headingMagnetic + deltaDegrees)
        courseOverGround = headingMagnetic
    }

    /// Demo-only: adjust the fake speed (e.g. from a vertical drag), clamped to 0–15 m/s (~0–29 kn).
    func demoAdjustSpeed(by deltaMetersPerSecond: Double) {
        speed = min(15, max(0, speed + deltaMetersPerSecond))
    }

    /// Demo-only: flip between port and starboard tack (mimics banking the phone the other way).
    /// Uses a default magnitude if heel is flat so a flip always changes tack.
    func demoFlipTack() {
        let magnitude = abs(heelDegrees) < 1 ? 14 : abs(heelDegrees)
        heelDegrees = heelDegrees <= 0 ? magnitude : -magnitude
    }
#endif

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            let raw = Heel.signedHeelDegrees(gravityX: g.x, gravityZ: g.z)
            self.heelDegrees += (raw - self.heelDegrees) * self.heelSmoothing
        }
    }

    /// Circular low-pass for heading, so 359° → 1° doesn't sweep the long way round.
    private func smoothHeading(toward new: Double) {
        let delta = Compass.signedDelta(new, headingMagnetic)
        headingMagnetic = Compass.normalize(headingMagnetic + delta * headingSmoothing)
    }
}

extension SensorManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let value = newHeading.magneticHeading
        Task { @MainActor in
            self.smoothHeading(toward: value)
            self.headingValid = true
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let course = loc.course            // -1 if invalid
        let spd = max(0, loc.speed)        // -1 if invalid → clamp to 0
        Task { @MainActor in
            self.courseOverGround = course >= 0 ? course : nil
            self.speed = spd
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationDenied = (status == .denied || status == .restricted)
        }
    }
}
