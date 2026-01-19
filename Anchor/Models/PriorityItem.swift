import Foundation
import SwiftData

@Model
final class PriorityItem {
    @Attribute(.unique) var id: UUID
    /// If this item is a "copy to backlog" created from another item, this links back to the source item's `id`.
    /// This allows us to avoid duplicating backlog copies and to show a UI indicator on the source day.
    var sourceItemId: UUID?
    var title: String
    var isCompleted: Bool
    var dateAssigned: Date? // nil = Backlog, Date = Assigned to that day
    var orderIndex: Int // For manual sorting within the day/backlog
    var notes: String?
    var calendarEventId: String? // Linked Google Calendar Event ID
    var calendarEventStartTime: Date? // Scheduled event start time (if scheduled)
    var createdAt: Date
    
    init(title: String, dateAssigned: Date? = nil, orderIndex: Int = 0, sourceItemId: UUID? = nil) {
        self.id = UUID()
        self.sourceItemId = sourceItemId
        self.title = title
        self.isCompleted = false
        self.dateAssigned = dateAssigned
        self.orderIndex = orderIndex
        self.createdAt = Date()
    }
}
