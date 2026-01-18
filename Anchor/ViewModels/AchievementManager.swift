import Foundation
import SwiftData
import SwiftUI

@Observable
class AchievementManager {
    var context: ModelContext
    var earnedAchievements: [Achievement] = []
    var userStats: UserStats?
    var newlyEarnedAchievement: Achievement?
    var showAchievementCelebration = false

    init(context: ModelContext) {
        self.context = context
        loadAchievements()
        loadOrCreateStats()
    }

    // MARK: - Loading Data

    func loadAchievements() {
        let descriptor = FetchDescriptor<Achievement>(
            sortBy: [SortDescriptor(\.earnedDate, order: .reverse)]
        )
        earnedAchievements = (try? context.fetch(descriptor)) ?? []
    }

    func loadOrCreateStats() {
        let descriptor = FetchDescriptor<UserStats>()
        if let existing = try? context.fetch(descriptor).first {
            userStats = existing
        } else {
            let newStats = UserStats()
            context.insert(newStats)
            userStats = newStats
            try? context.save()
        }
    }

    // MARK: - Achievement Checking

    func checkAndAwardAchievements(for streakCount: Int) {
        guard streakCount > 0 else { return }

        for achievementType in AchievementType.allCases {
            if streakCount >= achievementType.requiredStreak {
                awardAchievementIfNew(type: achievementType, streakCount: streakCount)
            }
        }
    }

    private func awardAchievementIfNew(type: AchievementType, streakCount: Int) {
        // Check if already earned
        let alreadyEarned = earnedAchievements.contains { $0.type == type }
        guard !alreadyEarned else { return }

        // Award the achievement
        let achievement = Achievement(type: type, earnedDate: Date(), streakCount: streakCount)
        context.insert(achievement)
        earnedAchievements.append(achievement)

        // Award freeze token for 7+ day achievements
        if type.requiredStreak >= 7 {
            userStats?.freezeTokens += 1
        }

        // Save and trigger celebration
        try? context.save()
        triggerAchievementCelebration(achievement)
    }

    private func triggerAchievementCelebration(_ achievement: Achievement) {
        newlyEarnedAchievement = achievement
        showAchievementCelebration = true

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
    }

    // MARK: - Stats Updates

    func updateStats(currentStreak: Int, top1Completed: Bool, allCompleted: Bool) {
        guard let stats = userStats else { return }

        if currentStreak > stats.longestStreak {
            stats.longestStreak = currentStreak
        }

        stats.currentStreak = currentStreak

        if top1Completed {
            stats.totalTop1Completed += 1
        }

        if allCompleted {
            stats.totalAllCompleted += 1
        }

        stats.lastUpdated = Date()
        try? context.save()
    }

    // MARK: - Freeze Token Usage

    func useFreezeToken() -> Bool {
        guard let stats = userStats, stats.freezeTokens > 0 else {
            return false
        }

        stats.freezeTokens -= 1
        try? context.save()
        return true
    }

    // MARK: - Helper Methods

    func hasEarned(_ type: AchievementType) -> Bool {
        earnedAchievements.contains { $0.type == type }
    }

    func nextMilestone(currentStreak: Int) -> AchievementType? {
        for type in AchievementType.allCases.sorted(by: { $0.requiredStreak < $1.requiredStreak }) {
            if currentStreak < type.requiredStreak {
                return type
            }
        }
        return nil
    }

    func daysUntilNextMilestone(currentStreak: Int) -> Int? {
        guard let next = nextMilestone(currentStreak: currentStreak) else {
            return nil
        }
        return next.requiredStreak - currentStreak
    }

    func dismissCelebration() {
        showAchievementCelebration = false
        newlyEarnedAchievement = nil
    }
}
