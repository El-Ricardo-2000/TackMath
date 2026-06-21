import Testing
@testable import TackAngle

/// Tests for the pure sailing math — the brain of the app. These cover the cases that are
/// invisible in the Simulator (sensors are dead there) and most prone to silent sign/wraparound
/// regressions. `@MainActor` because the app module builds with default MainActor isolation.
@MainActor
struct SailingMathTests {

    private func approxEqual(_ a: Double, _ b: Double, tol: Double = 1e-6) -> Bool {
        abs(a - b) < tol
    }

    // MARK: Compass angle math

    @Test func normalizeWrapsIntoZeroTo360() {
        #expect(approxEqual(Compass.normalize(0), 0))
        #expect(approxEqual(Compass.normalize(360), 0))
        #expect(approxEqual(Compass.normalize(370), 10))
        #expect(approxEqual(Compass.normalize(-10), 350))
        #expect(approxEqual(Compass.normalize(-370), 350))
        #expect(approxEqual(Compass.normalize(725), 5))
    }

    @Test func signedDeltaTakesShortWayAcrossNorth() {
        // 1° is 2° clockwise of 359°, not 358° the long way.
        #expect(approxEqual(Compass.signedDelta(1, 359), 2))
        #expect(approxEqual(Compass.signedDelta(359, 1), -2))
        #expect(approxEqual(Compass.signedDelta(10, 350), 20))
        #expect(approxEqual(Compass.signedDelta(0, 0), 0))
        // 180 is the boundary; result stays in (-180, 180].
        #expect(approxEqual(Compass.signedDelta(180, 0), 180))
        #expect(approxEqual(Compass.signedDelta(0, 180), 180))
    }

    @Test func separationIsSymmetricAndUnsigned() {
        #expect(approxEqual(Compass.separation(10, 350), 20))
        #expect(approxEqual(Compass.separation(350, 10), 20))
        #expect(approxEqual(Compass.separation(90, 270), 180))
    }

    // MARK: TackSolution geometry

    @Test func starboardTackPutsWindAndTackToTheRight() {
        let s = TackSolution(heading: 40, tack: .starboard, minAngle: 45)
        #expect(approxEqual(s.windBearing, 85))           // heading + minAngle
        #expect(approxEqual(s.oppositeTackBearing, 130))  // heading + 2*minAngle
    }

    @Test func portTackPutsWindAndTackToTheLeftWithWraparound() {
        let s = TackSolution(heading: 40, tack: .port, minAngle: 45)
        #expect(approxEqual(s.windBearing, 355))          // 40 - 45 → 355
        #expect(approxEqual(s.oppositeTackBearing, 310))  // 40 - 90 → 310
    }

    @Test func windBisectsHeadingAndOppositeTack() {
        for heading in stride(from: 0.0, to: 360.0, by: 37.0) {
            for angle in [22.0, 45.0, 60.0, 89.0] {
                for tack in [Tack.starboard, Tack.port] {
                    let s = TackSolution(heading: heading, tack: tack, minAngle: angle)
                    // Wind sits `angle` off the heading and `angle` off the opposite tack.
                    #expect(approxEqual(Compass.separation(s.windBearing, heading), angle))
                    #expect(approxEqual(Compass.separation(s.windBearing, s.oppositeTackBearing), angle))
                    // Opposite tack is 2*angle off the heading.
                    #expect(approxEqual(Compass.separation(s.oppositeTackBearing, heading), 2 * angle))
                }
            }
        }
    }

    // MARK: Heel → tack

    @Test func heelSignMapsGravityToTack() {
        // gravity.x > 0 → right side down → port tack (positive heel).
        let rightDown = Heel.signedHeelDegrees(gravityX: 0.5, gravityZ: -0.866)
        #expect(rightDown > 0)
        #expect(Heel.tack(forHeelDegrees: rightDown) == .port)

        // gravity.x < 0 → left side down → starboard tack (negative heel).
        let leftDown = Heel.signedHeelDegrees(gravityX: -0.5, gravityZ: -0.866)
        #expect(leftDown < 0)
        #expect(Heel.tack(forHeelDegrees: leftDown) == .starboard)
    }

    @Test func heelDeadBandReadsAsUnknown() {
        #expect(Heel.tack(forHeelDegrees: 0) == .unknown)
        #expect(Heel.tack(forHeelDegrees: 2) == .unknown)
        #expect(Heel.tack(forHeelDegrees: -2) == .unknown)
        #expect(Heel.tack(forHeelDegrees: 5) == .port)
        #expect(Heel.tack(forHeelDegrees: -5) == .starboard)
    }

    // MARK: Alignment

    @Test func alignmentIsUnknownWhenTooSlowOrNoCourse() {
        #expect(Alignment.isAligned(heading: 90, courseOverGround: 90, speed: 0.2) == nil)
        #expect(Alignment.isAligned(heading: 90, courseOverGround: nil, speed: 5) == nil)
    }

    @Test func alignmentComparesHeadingToCourseWithinTolerance() {
        #expect(Alignment.isAligned(heading: 90, courseOverGround: 100, speed: 5) == true)   // 10° off
        #expect(Alignment.isAligned(heading: 90, courseOverGround: 130, speed: 5) == false)  // 40° off
        // Tolerance straddles the wraparound seam too.
        #expect(Alignment.isAligned(heading: 5, courseOverGround: 355, speed: 5) == true)    // 10° off across N
    }
}
