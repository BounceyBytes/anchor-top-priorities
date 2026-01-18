import SwiftUI

struct AchievementCelebrationView: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotation: Double = -180
    @State private var confettiTrigger = 0

    private var iconColor: Color {
        switch achievement.type.color {
        case "orange": return .orange
        case "yellow": return .yellow
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "gold": return Color(red: 1.0, green: 0.84, blue: 0.0)
        default: return .white
        }
    }

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }

            // Confetti
            ConfettiCelebrationView(trigger: confettiTrigger)

            VStack(spacing: 24) {
                // Achievement icon with glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [iconColor.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)

                    // Icon background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.3), iconColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    // Icon
                    Image(systemName: achievement.type.icon)
                        .font(.system(size: 60))
                        .foregroundStyle(iconColor)
                }
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))

                VStack(spacing: 12) {
                    Text("Achievement Unlocked!")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))

                    Text(achievement.type.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [iconColor, iconColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text(achievement.type.description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    if achievement.type.requiredStreak >= 7 {
                        HStack(spacing: 8) {
                            Image(systemName: "snowflake")
                                .foregroundColor(.cyan)
                            Text("Earned 1 Freeze Token")
                                .font(.subheadline)
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.cyan.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.top, 8)
                    }
                }
                .opacity(opacity)

                Button(action: dismissWithAnimation) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(iconColor.opacity(0.8))
                        )
                }
                .opacity(opacity)
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .padding(32)
        }
        .onAppear {
            // Trigger confetti
            confettiTrigger += 1

            // Animate entrance
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                rotation = 0
            }

            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                opacity = 1.0
            }
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeIn(duration: 0.2)) {
            opacity = 0
            scale = 0.8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

/// Enhanced confetti view for achievements
struct ConfettiCelebrationView: View {
    let trigger: Int

    @State private var confettiPieces: [ConfettiPiece] = []

    struct ConfettiPiece: Identifiable {
        let id = UUID()
        var position: CGPoint
        var rotation: Double
        var velocity: CGPoint
        var color: Color
        var scale: CGFloat
        var opacity: Double = 1.0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    Circle()
                        .fill(piece.color)
                        .frame(width: 8 * piece.scale, height: 8 * piece.scale)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(piece.position)
                        .opacity(piece.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: trigger) { _, _ in
            createConfetti()
        }
    }

    private func createConfetti() {
        confettiPieces = []

        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

        for _ in 0..<80 {
            let piece = ConfettiPiece(
                position: CGPoint(x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                                y: -20),
                rotation: Double.random(in: 0...360),
                velocity: CGPoint(x: CGFloat.random(in: -2...2),
                                y: CGFloat.random(in: 3...8)),
                color: colors.randomElement() ?? .white,
                scale: CGFloat.random(in: 0.5...1.5)
            )
            confettiPieces.append(piece)
        }

        animateConfetti()
    }

    private func animateConfetti() {
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            for i in confettiPieces.indices {
                confettiPieces[i].position.x += confettiPieces[i].velocity.x
                confettiPieces[i].position.y += confettiPieces[i].velocity.y
                confettiPieces[i].rotation += 5
                confettiPieces[i].velocity.y += 0.2 // Gravity

                if confettiPieces[i].position.y > UIScreen.main.bounds.height + 50 {
                    confettiPieces[i].opacity = 0
                }
            }

            if confettiPieces.allSatisfy({ $0.opacity == 0 }) {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    AchievementCelebrationView(
        achievement: Achievement(
            type: .weekWarrior,
            streakCount: 7
        ),
        onDismiss: {}
    )
}
