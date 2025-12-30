import SwiftUI

private struct TickParticleSpec: Identifiable, Hashable {
    let id: Int
    let startX: CGFloat
    let driftX: CGFloat
    let delay: Double
    let duration: Double
    let size: CGFloat
    let rotation: Double
    let opacity: Double
}

struct TickRainView: View {
    private let count: Int
    @State private var specs: [TickParticleSpec] = []

    init(count: Int = 34) {
        self.count = count
    }

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            ZStack {
                ForEach(specs) { spec in
                    TickRainParticle(
                        spec: spec,
                        containerSize: geometry.size
                    )
                }
            }
            .frame(width: w, height: h)
            .onAppear {
                // Generate once so the animation feels stable (and doesn't "reshuffle" on re-render).
                guard specs.isEmpty else { return }
                specs = (0..<count).map { i in
                    TickParticleSpec(
                        id: i,
                        startX: CGFloat.random(in: 0...(max(1, w))),
                        driftX: CGFloat.random(in: -28...28),
                        delay: Double.random(in: 0.0...0.45),
                        duration: Double.random(in: 1.1...1.65),
                        size: CGFloat.random(in: 18...34),
                        rotation: Double.random(in: -14...14),
                        opacity: Double.random(in: 0.50...0.85)
                    )
                }
            }
        }
    }
}

private struct TickRainParticle: View {
    let spec: TickParticleSpec
    let containerSize: CGSize

    @State private var y: CGFloat = -40
    @State private var xOffset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.9

    var body: some View {
        let endY = containerSize.height + 60

        return Image(systemName: "checkmark.circle.fill")
            .font(.system(size: spec.size, weight: .semibold))
            .foregroundStyle(Color.green.opacity(spec.opacity))
            .rotationEffect(.degrees(spec.rotation))
            .scaleEffect(scale)
            .position(x: spec.startX, y: y)
            .offset(x: xOffset)
            .opacity(opacity)
            .onAppear {
                y = -40
                xOffset = 0
                opacity = 0
                scale = 0.92

                // Gentle fade-in + fall.
                withAnimation(.easeOut(duration: 0.18).delay(spec.delay)) {
                    opacity = 1
                    scale = 1.0
                }

                withAnimation(.linear(duration: spec.duration).delay(spec.delay)) {
                    y = endY
                    xOffset = spec.driftX
                }

                // Fade out near the end.
                let fadeDelay = spec.delay + max(0.0, spec.duration - 0.35)
                withAnimation(.easeOut(duration: 0.3).delay(fadeDelay)) {
                    opacity = 0
                }
            }
    }
}

extension View {
    func tickRain(trigger: Bool) -> some View {
        self.overlay(
            Group {
                if trigger {
                    TickRainView()
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            },
            alignment: .center
        )
    }
}
