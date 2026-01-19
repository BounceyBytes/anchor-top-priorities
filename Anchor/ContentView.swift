import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var priorityManager: PriorityManager?
    @State private var calendarManager = GoogleCalendarManager()
    @State private var showSplash = true
    @State private var splashOpacity: Double = 1.0
    @State private var mainViewOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Main app content (underneath)
            if let manager = priorityManager {
                AnchorMainView()
                    .environment(manager)
                    .environment(calendarManager)
                    .opacity(mainViewOpacity)
            }
            
            // Splash screen (on top, fades out)
            if showSplash {
                SplashScreenView(onComplete: dismissSplash)
                    .opacity(splashOpacity)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if priorityManager == nil {
                priorityManager = PriorityManager(modelContext: modelContext)
            }
        }
    }
    
    private func dismissSplash() {
        // Smooth crossfade transition
        withAnimation(.easeInOut(duration: 0.5)) {
            splashOpacity = 0
            mainViewOpacity = 1
        }
        
        // Remove splash from view hierarchy after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showSplash = false
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PriorityItem.self, inMemory: true)
        .preferredColorScheme(.dark)
}
