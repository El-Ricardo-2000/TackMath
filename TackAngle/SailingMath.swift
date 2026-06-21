import Foundation

/// Which tack the boat is on, inferred from how the boat (and the flat phone) is heeling.
///
/// Convention with the phone lying flat, screen up, top of phone pointing at the bow:
/// - Left side lower than right  → wind is coming over the port... no: see below.
///
/// Sailing convention used here:
/// - **Starboard tack**: wind comes over the *starboard* (right) side, so the boat heels to
///   *port* — the **left** side of the phone is lower. Right of way over port tack.
/// - **Port tack**: wind over the *port* (left) side, boat heels to *starboard* — the **right**
///   side of the phone is lower.
enum Tack: Equatable {
    case starboard   // left side low
    case port        // right side low
    case unknown     // too level to tell (within the heel dead-band)

    var label: String {
        switch self {
        case .starboard: return "Starboard tack"
        case .port: return "Port tack"
        case .unknown: return "Level — pick a tack"
        }
    }
}

enum Compass {
    /// Wrap any angle into [0, 360).
    static func normalize(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// Smallest signed difference `a - b` in (-180, 180]. Positive means `a` is clockwise of `b`.
    static func signedDelta(_ a: Double, _ b: Double) -> Double {
        var d = normalize(a) - normalize(b)
        if d > 180 { d -= 360 }
        if d <= -180 { d += 360 }
        return d
    }

    /// Absolute angular separation in [0, 180].
    static func separation(_ a: Double, _ b: Double) -> Double {
        abs(signedDelta(a, b))
    }
}

/// The full set of bearings the UI draws, derived purely from heading, tack, and the chosen
/// minimum angle off the wind. All values are compass degrees in [0, 360).
struct TackSolution: Equatable {
    let heading: Double          // current bow bearing
    let tack: Tack
    let minAngle: Double         // degrees off the wind (close-hauled angle)

    /// Implied true-wind bearing — the direction the wind is blowing *from*.
    let windBearing: Double
    /// Bearing you would sail on the opposite tack (the dashed tack line). `2 × minAngle` away.
    let oppositeTackBearing: Double

    init(heading: Double, tack: Tack, minAngle: Double) {
        self.heading = Compass.normalize(heading)
        self.tack = tack
        self.minAngle = minAngle

        // On starboard tack the wind is to the right of the bow (clockwise, +).
        // On port tack it is to the left (counter-clockwise, -).
        let sign: Double
        switch tack {
        case .starboard: sign = 1
        case .port: sign = -1
        case .unknown: sign = 1   // default to starboard so the UI still draws something
        }

        windBearing = Compass.normalize(self.heading + sign * minAngle)
        oppositeTackBearing = Compass.normalize(self.heading + sign * 2 * minAngle)
    }
}

enum Heel {
    /// Dead-band: below this many degrees of heel we can't reliably call the tack.
    static let deadBandDegrees = 3.0

    /// Signed heel from the gravity vector of a flat (screen-up) phone.
    /// `gravity` is CoreMotion's unit gravity vector in the device frame (x = right, y = bow, z = out of screen).
    /// Returns degrees: **positive = right side down (port tack)**, **negative = left side down (starboard tack)**.
    static func signedHeelDegrees(gravityX x: Double, gravityZ z: Double) -> Double {
        atan2(x, -z) * 180 / .pi
    }

    static func tack(forHeelDegrees heel: Double) -> Tack {
        if abs(heel) < deadBandDegrees { return .unknown }
        return heel < 0 ? .starboard : .port
    }
}

enum Alignment {
    /// Below this speed (m/s) course-over-ground is too noisy to trust, so we don't nag.
    static let minSpeed = 0.5
    /// Misalignment beyond this many degrees triggers the "rotate the phone" warning.
    static let toleranceDegrees = 25.0

    /// Is the bow arrow (phone heading) acceptably aligned with the GPS track?
    /// Returns nil when we can't judge (too slow / no course fix).
    static func isAligned(heading: Double, courseOverGround: Double?, speed: Double) -> Bool? {
        guard speed >= minSpeed, let cog = courseOverGround, cog >= 0 else { return nil }
        return Compass.separation(heading, cog) <= toleranceDegrees
    }
}
