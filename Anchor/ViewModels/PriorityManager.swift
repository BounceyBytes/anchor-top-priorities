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

    // MARK: - Backlog Copy Helpers

    private func normalizedTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Copies any *incomplete* items from past days into the backlog while keeping them on their original day.
    ///
    /// Business rules:
    /// - If a corresponding item already exists in the backlog, do not duplicate it.
    ///   We treat "already exists" as either:
    ///   - a backlog item whose `sourceItemId` matches the original item's `id`, OR
    ///   - a backlog item with the same normalized title (to avoid title-level duplication).
    func copyIncompletePastItemsToBacklogIfNeeded(referenceDate: Date = Date()) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: referenceDate)

        // 1) Fetch all backlog items once so we can do fast in-memory duplicate checks.
        let backlogDescriptor = FetchDescriptor<PriorityItem>(
            predicate: #Predicate<PriorityItem> { $0.dateAssigned == nil }
        )
        let backlogItems = (try? modelContext.fetch(backlogDescriptor)) ?? []

        var existingBacklogSourceIds = Set<UUID>()
        var existingBacklogTitles = Set<String>()

        for item in backlogItems {
            if let sourceId = item.sourceItemId {
                existingBacklogSourceIds.insert(sourceId)
            }
            existingBacklogTitles.insert(normalizedTitle(item.title))
        }

        // 2) Fetch all incomplete items assigned before today (i.e. past days).
        let pastIncompleteDescriptor = FetchDescriptor<PriorityItem>(
            predicate: #Predicate<PriorityItem> { item in
                item.dateAssigned != nil &&
                item.isCompleted == false &&
                item.dateAssigned! < todayStart
            },
            sortBy: [SortDescriptor(\.dateAssigned, order: .forward), SortDescriptor(\.orderIndex, order: .forward)]
        )

        let pastIncomplete = (try? modelContext.fetch(pastIncompleteDescriptor)) ?? []
        guard !pastIncomplete.isEmpty else { return }

        var didInsert = false
        for source in pastIncomplete {
            let sourceId = source.id
            let titleKey = normalizedTitle(source.title)

            // Avoid duplicating in backlog.
            if existingBacklogSourceIds.contains(sourceId) { continue }
            if existingBacklogTitles.contains(titleKey) { continue }

            let copy = PriorityItem(
                title: source.title,
                dateAssigned: nil,
                orderIndex: 0,
                sourceItemId: sourceId
            )
            copy.notes = source.notes
            // Do not copy calendar linkage/scheduling into backlog; backlog items are unscheduled by design.
            copy.calendarEventId = nil
            copy.calendarEventStartTime = nil
            copy.isCompleted = false

            modelContext.insert(copy)

            existingBacklogSourceIds.insert(sourceId)
            existingBacklogTitles.insert(titleKey)
            didInsert = true
        }

        if didInsert {
            try? modelContext.save()
        }
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
