import SwiftUI

struct ContentView: View {
    @State private var sensors = SensorManager()
    @AppStorage("minAngle") private var minAngle: Double = 45
    @AppStorage("nightMode") private var nightMode: Bool = false
#if DEBUG
    @AppStorage("demoMode") private var demoMode: Bool = false
    @State private var demoDragLastX: CGFloat = 0
    @State private var demoDragLastY: CGFloat = 0
#endif

    private var palette: Palette { nightMode ? .night : .day }

    /// Starts the real sensor feeds, or the DEBUG demo feed when demo mode is on
    /// (for capturing Simulator screenshots — sensors are dead in the Simulator).
    private func startSensors() {
#if DEBUG
        if demoMode { sensors.startDemo(); return }
#endif
        sensors.start()
    }

#if DEBUG
    /// Demo-only: drag across the compass to pose the screen — horizontal spins the heading
    /// (0.5°/pt), vertical changes speed (up = faster, 0.03 m/s per pt).
    private var demoRotateGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let dx = value.translation.width - demoDragLastX
                let dy = value.translation.height - demoDragLastY
                sensors.demoAdjustHeading(by: Double(dx) * 0.5)
                sensors.demoAdjustSpeed(by: Double(-dy) * 0.03)   // drag up → faster
                demoDragLastX = value.translation.width
                demoDragLastY = value.translation.height
            }
            .onEnded { _ in demoDragLastX = 0; demoDragLastY = 0 }
    }
#endif

    private var tack: Tack {
        Heel.tack(forHeelDegrees: sensors.heelDegrees)
    }

    private var solution: TackSolution {
        TackSolution(heading: sensors.headingMagnetic, tack: tack, minAngle: minAngle)
    }

    private var alignment: Bool? {
        Alignment.isAligned(heading: sensors.headingMagnetic,
                            courseOverGround: sensors.courseOverGround,
                            speed: sensors.speed)
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 12) {
                topBar

                header

                if alignment == false {
                    warningBanner
                }

                CompassView(heading: sensors.headingMagnetic, solution: solution, palette: palette)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
#if DEBUG
                    .contentShape(Rectangle())   // make the whole compass area draggable/tappable
                    .gesture(demoMode ? demoRotateGesture : nil)
                    .onTapGesture(count: 2) { if demoMode { sensors.demoFlipTack() } }
#endif

                windReadout

                dial

                footer
            }
            .padding()
        }
        .preferredColorScheme(nightMode ? .dark : nil)
        .onAppear {
            startSensors()
            UIApplication.shared.isIdleTimerDisabled = true   // keep screen awake while sailing
        }
        .onDisappear {
            sensors.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var topBar: some View {
        HStack {
            Text("TACK MATH")
                .font(.headline)
                .foregroundStyle(palette.secondaryText)
#if DEBUG
                .onLongPressGesture {
                    demoMode.toggle()
                    startSensors()
                }
#endif
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { nightMode.toggle() }
            } label: {
                Image(systemName: nightMode ? "sun.max.fill" : "moon.fill")
                    .font(.title3)
                    .foregroundStyle(palette.primaryText)
            }
            .accessibilityLabel(nightMode ? "Switch to day mode" : "Switch to night mode")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("HEADING")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                Text(String(format: "%03.0f°M", sensors.headingMagnetic))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .monospacedDigit()
            }
            Spacer()
            readout("TACK", value: tackShort, tint: tackColor)
        }
    }

    private var windReadout: some View {
        VStack(spacing: 2) {
            Text("TACK ONTO")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            Text(String(format: "%03.0f°", solution.oppositeTackBearing))
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.tackNumber)
                .monospacedDigit()
            Text("Implied wind \(String(format: "%03.0f°", solution.windBearing))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(palette.wind)
                .monospacedDigit()
        }
    }

    private var dial: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Min angle off wind")
                    .font(.subheadline)
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Text("\(Int(minAngle))°")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.primaryText)
                    .monospacedDigit()
            }
            Slider(value: $minAngle, in: 20...89, step: 1)
                .tint(palette.wind)
        }
    }

    private var footer: some View {
        HStack {
            readout("HEEL", value: String(format: "%.0f°", abs(sensors.heelDegrees)))
            Spacer()
            readout("COG", value: sensors.courseOverGround.map { String(format: "%03.0f°", $0) } ?? "—")
            Spacer()
            readout("SPEED", value: String(format: "%.1f kn", sensors.speed * 1.94384))
        }
        .font(.footnote)
    }

    private var warningBanner: some View {
        Label("Bow arrow isn't aligned with your track — rotate the phone so the top points at the bow.",
              systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.red, in: RoundedRectangle(cornerRadius: 10))
    }

    private func readout(_ title: String, value: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint ?? palette.primaryText)
                .monospacedDigit()
        }
    }

    private var tackShort: String {
        switch tack {
        case .starboard: return "STBD"
        case .port: return "PORT"
        case .unknown: return "—"
        }
    }

    private var tackColor: Color {
        switch tack {
        case .starboard: return nightMode ? palette.tackLine : .green
        case .port: return nightMode ? palette.north : .red
        case .unknown: return palette.secondaryText
        }
    }
}

#Preview {
    ContentView()
}
