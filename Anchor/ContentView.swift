import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var priorityManager: PriorityManager?
    @State private var calendarManager = GoogleCalendarManager()
    
    var body: some View {
        Group {
            if let manager = priorityManager {
                AnchorMainView()
                    .environment(manager)
                    .environment(calendarManager)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if priorityManager == nil {
                priorityManager = PriorityManager(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PriorityItem.self, inMemory: true)
        .preferredColorScheme(.dark)
}
