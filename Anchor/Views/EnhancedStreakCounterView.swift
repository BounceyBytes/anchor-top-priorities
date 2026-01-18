import SwiftUI

struct EnhancedStreakCounterView: View {
    let streakCount: Int
    let nextMilestone: AchievementType?
    let daysUntilMilestone: Int?
    let isAtRisk: Bool

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            // Flame icon
            StreakFlameView(streakCount: streakCount)
                .scaleEffect(isAtRisk ? pulseScale : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                // Streak count
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streakCount)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(isAtRisk ? .orange : .white)

                    Text("day\(streakCount == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Next milestone or risk warning
                if isAtRisk {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("Streak at risk!")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                } else if let milestone = nextMilestone, let days = daysUntilMilestone {
                    HStack(spacing: 4) {
                        Image(systemName: milestone.icon)
                            .font(.system(size: 10))
                        Text("\(days) more for \(milestone.title)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isAtRisk ? Color.orange.opacity(0.3) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            if isAtRisk {
                withAnimation(
                    Animation.easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                ) {
                    pulseScale = 1.1
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        EnhancedStreakCounterView(
            streakCount: 5,
            nextMilestone: .weekWarrior,
            daysUntilMilestone: 2,
            isAtRisk: false
        )

        EnhancedStreakCounterView(
            streakCount: 12,
            nextMilestone: .twoWeekTitan,
            daysUntilMilestone: 2,
            isAtRisk: true
        )

        EnhancedStreakCounterView(
            streakCount: 28,
            nextMilestone: .monthMaster,
            daysUntilMilestone: 2,
            isAtRisk: false
        )
    }
    .padding()
    .background(Color.black)
}
