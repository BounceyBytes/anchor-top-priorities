import Foundation
import SwiftData

@Model
final class PriorityItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var dateAssigned: Date? // nil = Backlog, Date = Assigned to that day
    var orderIndex: Int // For manual sorting within the day/backlog
    var notes: String?
    var calendarEventId: String? // Linked Google Calendar Event ID
    var calendarEventStartTime: Date? // Scheduled event start time (if scheduled)
    var createdAt: Date
    
    init(title: String, dateAssigned: Date? = nil, orderIndex: Int = 0) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.dateAssigned = dateAssigned
        self.orderIndex = orderIndex
        self.createdAt = Date()
    }
}
