import Foundation
import SwiftData

/// Represents different types of achievements users can earn
enum AchievementType: String, Codable, CaseIterable {
    case fireStarter = "fire_starter"       // 3-day streak
    case weekWarrior = "week_warrior"       // 7-day streak
    case twoWeekTitan = "two_week_titan"    // 14-day streak
    case monthMaster = "month_master"       // 30-day streak
    case doubleMonth = "double_month"       // 60-day streak
    case centuryClub = "century_club"       // 100-day streak
    case yearChampion = "year_champion"     // 365-day streak

    var title: String {
        switch self {
        case .fireStarter: return "Fire Starter"
        case .weekWarrior: return "Week Warrior"
        case .twoWeekTitan: return "Two Week Titan"
        case .monthMaster: return "Month Master"
        case .doubleMonth: return "Double Month"
        case .centuryClub: return "Century Club"
        case .yearChampion: return "Year Champion"
        }
    }

    var description: String {
        switch self {
        case .fireStarter: return "Complete your #1 priority for 3 days straight"
        case .weekWarrior: return "Maintain a 7-day streak"
        case .twoWeekTitan: return "Keep going for 14 days"
        case .monthMaster: return "Achieve a 30-day streak"
        case .doubleMonth: return "Unstoppable for 60 days"
        case .centuryClub: return "100 days of dedication"
        case .yearChampion: return "A full year of excellence"
        }
    }

    var requiredStreak: Int {
        switch self {
        case .fireStarter: return 3
        case .weekWarrior: return 7
        case .twoWeekTitan: return 14
        case .monthMaster: return 30
        case .doubleMonth: return 60
        case .centuryClub: return 100
        case .yearChampion: return 365
        }
    }

    var icon: String {
        switch self {
        case .fireStarter: return "flame"
        case .weekWarrior: return "bolt.fill"
        case .twoWeekTitan: return "star.fill"
        case .monthMaster: return "crown.fill"
        case .doubleMonth: return "gem.fill"
        case .centuryClub: return "trophy.fill"
        case .yearChampion: return "medal.fill"
        }
    }

    var color: String {
        switch self {
        case .fireStarter: return "orange"
        case .weekWarrior: return "yellow"
        case .twoWeekTitan: return "blue"
        case .monthMaster: return "purple"
        case .doubleMonth: return "pink"
        case .centuryClub: return "gold"
        case .yearChampion: return "rainbow"
        }
    }
}

/// Stores earned achievements
@Model
final class Achievement {
    var id: UUID
    var type: AchievementType
    var earnedDate: Date
    var streakCount: Int // The streak count when earned

    init(type: AchievementType, earnedDate: Date = Date(), streakCount: Int) {
        self.id = UUID()
        self.type = type
        self.earnedDate = earnedDate
        self.streakCount = streakCount
    }
}

/// Stores user statistics and progress
@Model
final class UserStats {
    var id: UUID
    var longestStreak: Int
    var currentStreak: Int
    var totalTop1Completed: Int
    var totalAllCompleted: Int
    var freezeTokens: Int
    var lastUpdated: Date

    init() {
        self.id = UUID()
        self.longestStreak = 0
        self.currentStreak = 0
        self.totalTop1Completed = 0
        self.totalAllCompleted = 0
        self.freezeTokens = 0
        self.lastUpdated = Date()
    }
}
