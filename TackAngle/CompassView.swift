import SwiftUI

/// Bow-up compass rose. The top of the view is always the bow; the rose (tick marks) rotates under
/// it as the boat turns. Cardinal labels are billboarded upright so they stay readable at any
/// heading. Wind and tack overlays are drawn at their bearing *relative* to the current heading.
struct CompassView: View {
    let heading: Double
    let solution: TackSolution
    let palette: Palette

    private let cardinals: [(String, Double)] = [("N", 0), ("E", 90), ("S", 180), ("W", 270)]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let r = size / 2
            ZStack {
                // Rotating tick ring (bow-up): rotate opposite to heading.
                RoseCard(palette: palette)
                    .rotationEffect(.degrees(-heading))

                // Cardinal letters: positioned around the ring but kept upright (billboarded).
                ForEach(cardinals, id: \.0) { name, bearing in
                    let rel = Compass.signedDelta(bearing, heading)
                    Text(name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(name == "N" ? palette.north : palette.primaryText)
                        .rotationEffect(.degrees(-rel))     // keep glyph upright
                        .offset(y: -r + 34)
                        .rotationEffect(.degrees(rel))       // place around the ring
                }

                // Implied wind direction (solid) — points FROM the wind, toward the boat.
                WindArrow(palette: palette)
                    .rotationEffect(.degrees(Compass.signedDelta(solution.windBearing, heading)))

                // Opposite-tack line (dashed) — where you'd point after tacking.
                TackLine(palette: palette)
                    .rotationEffect(.degrees(Compass.signedDelta(solution.oppositeTackBearing, heading)))

                // Fixed bow arrow pinned at the top.
                BowArrow(palette: palette)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The rotating dial: outer ring and tick marks every 5° (90° marks emphasised).
private struct RoseCard: View {
    let palette: Palette

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let r = s / 2
            ZStack {
                Circle()
                    .strokeBorder(palette.card, lineWidth: 2)

                ForEach(0..<72) { i in
                    let isMajor = i % 9 == 0          // every 90°
                    let isMid = i % 3 == 0            // every 30°
                    Rectangle()
                        .fill(palette.card.opacity(isMajor ? 1 : 0.7))
                        .frame(width: isMajor ? 3 : 1.5,
                               height: isMajor ? 16 : (isMid ? 11 : 6))
                        .offset(y: -r + (isMajor ? 8 : 5))
                        .rotationEffect(.degrees(Double(i) * 5))
                }
            }
            .frame(width: s, height: s)
        }
    }
}

/// Fixed arrow at the top of the screen indicating the bow.
private struct BowArrow: View {
    let palette: Palette

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            VStack(spacing: 2) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(palette.bow)
                Text("BOW")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(palette.bow)
            }
            .position(x: geo.size.width / 2, y: (geo.size.height - s) / 2 + 4)
        }
    }
}

/// Solid wind-direction arrow drawn near the rim (wind blows *toward* the boat).
private struct WindArrow: View {
    let palette: Palette

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let r = s / 2
            ZStack {
                Image(systemName: "arrow.down")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(palette.wind)
                    .offset(y: -r + 30)
                Text("WIND")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.wind)
                    .offset(y: -r + 56)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Dashed line marking the heading on the opposite tack.
private struct TackLine: View {
    let palette: Palette

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let r = s / 2
            Path { p in
                p.move(to: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                p.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 - r + 14))
            }
            .stroke(palette.tackLine, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
        }
    }
}

#Preview {
    CompassView(
        heading: 40,
        solution: TackSolution(heading: 40, tack: .starboard, minAngle: 45),
        palette: .day
    )
    .padding()
}
