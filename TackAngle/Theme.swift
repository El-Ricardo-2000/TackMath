import SwiftUI

/// Color palette for the app. Day mode is the normal bright scheme; night mode is an all-red,
/// low-luminance scheme to preserve dark-adapted night vision while sailing after dark.
struct Palette {
    let background: Color
    let card: Color          // compass ring + tick marks
    let primaryText: Color
    let secondaryText: Color
    let bow: Color
    let north: Color
    let wind: Color
    let tackLine: Color
    let tackNumber: Color

    static let day = Palette(
        background: Color(.systemBackground),
        card: Color.secondary.opacity(0.5),
        primaryText: .primary,
        secondaryText: .secondary,
        bow: .blue,
        north: .red,
        wind: .orange,
        tackLine: .green,
        tackNumber: .green
    )

    /// Red-on-black. Shapes (solid wind arrow vs dashed tack line vs bow arrow) carry the meaning;
    /// hue stays in the red band so the display doesn't kill night vision.
    static let night = Palette(
        background: .black,
        card: Color(red: 0.55, green: 0.05, blue: 0.05),
        primaryText: Color(red: 1.00, green: 0.27, blue: 0.21),
        secondaryText: Color(red: 0.85, green: 0.22, blue: 0.18),
        bow: Color(red: 1.00, green: 0.45, blue: 0.30),
        north: Color(red: 1.00, green: 0.32, blue: 0.26),
        wind: Color(red: 1.00, green: 0.50, blue: 0.25),
        tackLine: Color(red: 1.00, green: 0.38, blue: 0.32),
        tackNumber: Color(red: 1.00, green: 0.35, blue: 0.28)
    )
}
