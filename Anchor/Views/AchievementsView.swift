import SwiftUI

struct AchievementsView: View {
    @Environment(AchievementManager.self) private var achievementManager
    @Environment(PriorityManager.self) private var priorityManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Stats Section
                    statsSection

                    // Achievements Grid
                    achievementsSection

                    // Freeze Tokens
                    freezeTokensSection
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(spacing: 16) {
            Text("Your Stats")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Current Streak",
                    value: "\(priorityManager.calculateCurrentStreak())",
                    icon: "flame.fill",
                    color: .orange
                )

                StatCard(
                    title: "Longest Streak",
                    value: "\(achievementManager.userStats?.longestStreak ?? 0)",
                    icon: "trophy.fill",
                    color: .yellow
                )

                StatCard(
                    title: "Top 1 Completed",
                    value: "\(achievementManager.userStats?.totalTop1Completed ?? 0)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatCard(
                    title: "All 3 Completed",
                    value: "\(achievementManager.userStats?.totalAllCompleted ?? 0)",
                    icon: "star.fill",
                    color: .blue
                )
            }
        }
    }

    private var achievementsSection: some View {
        VStack(spacing: 16) {
            Text("Achievements")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(AchievementType.allCases, id: \.self) { type in
                    AchievementCard(
                        type: type,
                        isEarned: achievementManager.hasEarned(type),
                        achievement: achievementManager.earnedAchievements.first { $0.type == type }
                    )
                }
            }
        }
    }

    private var freezeTokensSection: some View {
        VStack(spacing: 12) {
            Text("Freeze Tokens")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(0..<min(achievementManager.userStats?.freezeTokens ?? 0, 5), id: \.self) { _ in
                            Image(systemName: "snowflake")
                                .font(.title2)
                                .foregroundColor(.cyan)
                        }

                        if (achievementManager.userStats?.freezeTokens ?? 0) > 5 {
                            Text("+\((achievementManager.userStats?.freezeTokens ?? 0) - 5)")
                                .font(.headline)
                                .foregroundColor(.cyan)
                        }
                    }

                    Text("Protect your streak from breaking")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Text("\(achievementManager.userStats?.freezeTokens ?? 0)")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.cyan)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cyan.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct AchievementCard: View {
    let type: AchievementType
    let isEarned: Bool
    let achievement: Achievement?

    private var iconColor: Color {
        guard isEarned else { return .gray }

        switch type.color {
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
        VStack(spacing: 12) {
            ZStack {
                if isEarned {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [iconColor.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                }

                Image(systemName: type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isEarned ? iconColor : .gray.opacity(0.3))
            }

            Text(type.title)
                .font(.headline)
                .foregroundColor(isEarned ? .white : .gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text("\(type.requiredStreak) days")
                .font(.caption)
                .foregroundColor(isEarned ? .white.opacity(0.6) : .gray.opacity(0.4))

            if let achievement = achievement {
                Text(achievement.earnedDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isEarned ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isEarned ? iconColor.opacity(0.3) : Color.white.opacity(0.05),
                            lineWidth: isEarned ? 1.5 : 1
                        )
                )
        )
        .opacity(isEarned ? 1.0 : 0.5)
    }
}

#Preview {
    AchievementsView()
        .modelContainer(for: [Achievement.self, UserStats.self], inMemory: true)
}
