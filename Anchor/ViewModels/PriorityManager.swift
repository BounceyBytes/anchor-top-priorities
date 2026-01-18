import Foundation
import SwiftData
import SwiftUI

@Observable
class PriorityManager {
    var modelContext: ModelContext
    var showSchedulingPrompt: Bool = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Ordering Helpers
    
    private func itemsAssigned(on date: Date) -> [PriorityItem] {
        let descriptor = FetchDescriptor<PriorityItem>(
            predicate: #Predicate<PriorityItem> { $0.dateAssigned != nil },
            sortBy: [
                SortDescriptor(\.dateAssigned),
                SortDescriptor(\.orderIndex, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )
        
        let assigned = (try? modelContext.fetch(descriptor)) ?? []
        let calendar = Calendar.current
        
        return assigned.filter { item in
            guard let d = item.dateAssigned else { return false }
            return calendar.isDate(d, inSameDayAs: date)
        }
    }
    
    private func nextOrderIndex(for date: Date) -> Int {
        let items = itemsAssigned(on: date)
        return (items.map(\.orderIndex).max() ?? -1) + 1
    }
    
    /// Ensures `orderIndex` is unique + sequential (0...n-1) for items on the given day.
    /// This prevents unstable ordering when multiple items accidentally share the same `orderIndex`.
    private func normalizeOrderIndexes(for date: Date) {
        let items = itemsAssigned(on: date).sorted { a, b in
            if a.orderIndex != b.orderIndex { return a.orderIndex < b.orderIndex }
            return a.createdAt < b.createdAt
        }
        
        for (index, item) in items.enumerated() {
            item.orderIndex = index
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Actions
    
    /// Checks if a date has reached the maximum of 3 tasks
    private func hasReachedLimit(for date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<PriorityItem> { item in
            item.dateAssigned != nil && item.dateAssigned! >= startOfDay && item.dateAssigned! < endOfDay
        }
        
        let descriptor = FetchDescriptor<PriorityItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.orderIndex, order: .reverse)]
        )
        
        let dateItems = (try? modelContext.fetch(descriptor)) ?? []
        return dateItems.count >= 3
    }
    
    func addPriority(title: String, toBacklog: Bool = true, for date: Date = Date()) throws {
        // If adding to a specific date (not backlog), check the limit
        if !toBacklog {
            if hasReachedLimit(for: date) {
                throw PriorityError.dailyLimitReached
            }
        }
        
        let newItem = PriorityItem(title: title, dateAssigned: toBacklog ? nil : date)
        if !toBacklog {
            newItem.orderIndex = nextOrderIndex(for: date)
        }
        modelContext.insert(newItem)
        try? modelContext.save()
        
        if !toBacklog {
            normalizeOrderIndexes(for: date)
        }
    }
    
    /// Moves an item to a specific date, enforcing the 3-task limit
    func moveToDate(_ item: PriorityItem, date: Date) throws {
        // Check if the target date already has 3 tasks
        if hasReachedLimit(for: date) {
            throw PriorityError.dailyLimitReached
        }
        
        item.dateAssigned = date
        item.orderIndex = nextOrderIndex(for: date)
        try? modelContext.save()
        normalizeOrderIndexes(for: date)
    }
    
    func moveToToday(_ item: PriorityItem) throws {
        try moveToDate(item, date: Date())
    }
    
    func moveToBacklog(_ item: PriorityItem) {
        // Keep `orderIndex` as-is (backlog order is based on `createdAt`),
        // but persist the move.
        item.dateAssigned = nil
        try? modelContext.save()
    }
    
    func puntToTomorrow(_ item: PriorityItem) throws {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return }
        // Check if tomorrow already has 3 tasks
        if hasReachedLimit(for: tomorrow) {
            throw PriorityError.dailyLimitReached
        }
        item.dateAssigned = tomorrow
        item.orderIndex = nextOrderIndex(for: tomorrow)
        try? modelContext.save()
        normalizeOrderIndexes(for: tomorrow)
    }
    
    func toggleCompletion(_ item: PriorityItem) {
        item.isCompleted.toggle()
        // Determine if we should keep it in the list or move to history
        // For now, we keep it but visually mark it
        try? modelContext.save()
    }
    
    func reorderPriorities(_ items: [PriorityItem]) {
        // Update orderIndex for each item based on its new position
        for (index, item) in items.enumerated() {
            item.orderIndex = index
        }
        try? modelContext.save()
    }
    
    func deletePriority(_ item: PriorityItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    func renamePriority(_ item: PriorityItem, to newTitle: String) {
        item.title = newTitle
        try? modelContext.save()
    }
    
    // MARK: - Recovery Logic
    
    /// Enforces the 3-priority limit for a given date by moving excess priorities to backlog
    func enforcePriorityLimit(for date: Date) {
        let priorities = getPriorities(for: date)
        
        // If we have more than 3 priorities, move the excess to backlog
        if priorities.count > 3 {
            let excessPriorities = priorities.suffix(from: 3) // Items at index 3 and beyond
            
            for item in excessPriorities {
                item.dateAssigned = nil // Move to backlog
            }
            
            try? modelContext.save()
        }
    }
    
    /// Enforces priority limits for all dates (useful for recovery on app launch)
    func enforceAllPriorityLimits() {
        // Get all assigned items
        let descriptor = FetchDescriptor<PriorityItem>(
            predicate: #Predicate<PriorityItem> { $0.dateAssigned != nil },
            sortBy: [SortDescriptor(\.dateAssigned), SortDescriptor(\.orderIndex)]
        )
        
        guard let allAssigned = try? modelContext.fetch(descriptor) else { return }
        
        // Group by date
        let calendar = Calendar.current
        var itemsByDate: [Date: [PriorityItem]] = [:]
        
        for item in allAssigned {
            guard let assignedDate = item.dateAssigned else { continue }
            let dayStart = calendar.startOfDay(for: assignedDate)
            
            if itemsByDate[dayStart] == nil {
                itemsByDate[dayStart] = []
            }
            itemsByDate[dayStart]?.append(item)
        }
        
        // Enforce limit for each date
        for (date, items) in itemsByDate {
            let sortedItems = items.sorted { $0.orderIndex < $1.orderIndex }
            
            if sortedItems.count > 3 {
                let excessItems = sortedItems.suffix(from: 3)
                for item in excessItems {
                    item.dateAssigned = nil // Move to backlog
                }
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Query Helpers
    
    func getPriorities(for date: Date) -> [PriorityItem] {
        // Use an optimized query with a predicate instead of fetching all items
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<PriorityItem> { item in
            item.dateAssigned != nil && item.dateAssigned! >= startOfDay && item.dateAssigned! < endOfDay
        }
        
        let descriptor = FetchDescriptor<PriorityItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.orderIndex, order: .forward)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func getCompletionStatus(for date: Date) -> (top1: Bool, top2: Bool, top3: Bool) {
        let priorities = getPriorities(for: date)
        let top1 = priorities.count > 0 && priorities[0].isCompleted
        let top2 = priorities.count > 1 && priorities[1].isCompleted
        let top3 = priorities.count > 2 && priorities[2].isCompleted
        return (top1, top2, top3)
    }
    
    func getStreakLength(endingAt date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)
        
        // Only calculate streaks for today or past dates
        guard targetDate <= today else { return 0 }
        
        // First, find the start of the streak by going backwards
        var currentDate = targetDate
        var daysBack = 0
        
        while true {
            let status = getCompletionStatus(for: currentDate)
            if status.top1 {
                daysBack += 1
                if let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                    currentDate = previousDay
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        // If this day doesn't have top1 completed, no streak
        if daysBack == 0 {
            return 0
        }
        
        // Now find the end of the streak by going forwards (up to today)
        let startDate = calendar.date(byAdding: .day, value: -(daysBack - 1), to: targetDate) ?? targetDate
        var forwardDate = startDate
        var totalStreak = 0
        
        while forwardDate <= today {
            let status = getCompletionStatus(for: forwardDate)
            if status.top1 {
                totalStreak += 1
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: forwardDate) {
                    forwardDate = nextDay
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return totalStreak
    }

    // MARK: - Streak Risk Detection

    /// Checks if the current streak is at risk (today's #1 priority incomplete and it's late in the day)
    func isStreakAtRisk(for date: Date = Date()) -> Bool {
        let calendar = Calendar.current

        // Only check for today
        guard calendar.isDateInToday(date) else { return false }

        // Check time of day
        let hour = calendar.component(.hour, from: Date())
        guard hour >= 18 else { return false } // After 6pm

        // Check if #1 priority exists and is incomplete
        let priorities = getPriorities(for: date)
        guard let top1 = priorities.first else { return true } // No task = at risk

        return !top1.isCompleted
    }

    /// Returns the risk level based on time of day
    func streakRiskLevel() -> StreakRiskLevel {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        let priorities = getPriorities(for: Date())
        let top1Incomplete = priorities.first.map { !$0.isCompleted } ?? true

        guard top1Incomplete else { return .safe }

        if hour >= 23 {
            return .critical
        } else if hour >= 21 {
            return .high
        } else if hour >= 18 {
            return .warning
        } else {
            return .safe
        }
    }
}

enum StreakRiskLevel {
    case safe
    case warning    // After 6pm
    case high       // After 9pm
    case critical   // After 11pm
}

enum PriorityError: Error, LocalizedError {
    case dailyLimitReached
    
    var errorDescription: String? {
        switch self {
        case .dailyLimitReached:
            return "This day already has 3 priorities. Finish one or move it to backlog first."
        }
    }
}
