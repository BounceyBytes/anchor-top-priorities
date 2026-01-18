import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct AnchorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PriorityItem.self,
            Achievement.self,
            UserStats.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
