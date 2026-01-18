import SwiftUI

struct StreakFlameView: View {
    let streakCount: Int
    @State private var isAnimating = false
    @State private var particleOffset: CGFloat = 0

    private var flameSize: CGFloat {
        switch streakCount {
        case 0: return 0
        case 1...6: return 32
        case 7...13: return 40
        case 14...29: return 48
        case 30...99: return 56
        default: return 64
        }
    }

    private var flameColor: Color {
        switch streakCount {
        case 0: return .clear
        case 1...6: return Color.orange
        case 7...13: return Color.yellow
        case 14...29: return Color.red
        case 30...99: return Color.purple
        default: return Color.blue // Hottest flame
        }
    }

    private var secondaryColor: Color {
        switch streakCount {
        case 0: return .clear
        case 1...6: return Color.red
        case 7...13: return Color.orange
        case 14...29: return Color.orange
        case 30...99: return Color.pink
        default: return Color.cyan
        }
    }

    var body: some View {
        ZStack {
            // Glow effect
            if streakCount > 0 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [flameColor.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: flameSize * 0.8
                        )
                    )
                    .frame(width: flameSize * 1.6, height: flameSize * 1.6)
                    .blur(radius: 8)
                    .opacity(isAnimating ? 0.6 : 0.3)
            }

            // Main flame
            ZStack {
                // Base flame
                FlameShape()
                    .fill(
                        LinearGradient(
                            colors: [flameColor, secondaryColor],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: flameSize * 0.7, height: flameSize)
                    .scaleEffect(x: isAnimating ? 1.1 : 0.9, y: isAnimating ? 1.15 : 0.95)

                // Inner flame highlight
                FlameShape()
                    .fill(
                        LinearGradient(
                            colors: [.white, flameColor.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: flameSize * 0.4, height: flameSize * 0.7)
                    .offset(y: flameSize * 0.1)
                    .scaleEffect(x: isAnimating ? 0.9 : 1.1, y: isAnimating ? 0.95 : 1.1)

                // Particles for higher streaks
                if streakCount >= 7 {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(flameColor.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .offset(
                                x: CGFloat.random(in: -flameSize * 0.3...flameSize * 0.3),
                                y: particleOffset - CGFloat(index * 10)
                            )
                            .opacity(1 - (particleOffset / flameSize))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }

            // Particle animation for higher streaks
            if streakCount >= 7 {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    particleOffset = -flameSize
                }
            }
        }
    }
}

/// Custom flame shape
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // Start at bottom center
        path.move(to: CGPoint(x: width * 0.5, y: height))

        // Left curve
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: 0),
            control1: CGPoint(x: 0, y: height * 0.75),
            control2: CGPoint(x: width * 0.2, y: height * 0.25)
        )

        // Right curve
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: width * 0.8, y: height * 0.25),
            control2: CGPoint(x: width, y: height * 0.75)
        )

        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 30) {
        HStack(spacing: 20) {
            VStack {
                StreakFlameView(streakCount: 1)
                Text("Day 1")
                    .font(.caption)
            }
            VStack {
                StreakFlameView(streakCount: 5)
                Text("Day 5")
                    .font(.caption)
            }
            VStack {
                StreakFlameView(streakCount: 10)
                Text("Day 10")
                    .font(.caption)
            }
        }

        HStack(spacing: 20) {
            VStack {
                StreakFlameView(streakCount: 20)
                Text("Day 20")
                    .font(.caption)
            }
            VStack {
                StreakFlameView(streakCount: 50)
                Text("Day 50")
                    .font(.caption)
            }
            VStack {
                StreakFlameView(streakCount: 150)
                Text("Day 150")
                    .font(.caption)
            }
        }
    }
    .padding()
    .background(Color.black)
}
