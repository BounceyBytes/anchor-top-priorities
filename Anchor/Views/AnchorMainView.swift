import SwiftUI
import SwiftData

enum ViewMode {
    case day
    case monthly
}

struct AnchorMainView: View {
    @Environment(PriorityManager.self) private var priorityManager
    @Environment(GoogleCalendarManager.self) private var calendarManager
    @Query(filter: #Predicate<PriorityItem> { $0.dateAssigned != nil }, sort: \.orderIndex)
    private var allAssignedItems: [PriorityItem]
    
    @State private var selectedDate: Date = Date()
    @State private var viewMode: ViewMode = .day
    @State private var showFullScreenBacklog: Bool = false
    @State private var backlogDraftTitle: String = ""
    @State private var backlogInputFocusRequested: Bool = false
    @State private var backlogVisibleHeight: CGFloat = 0
    
    // Swipe-to-navigate header animation state.
    @State private var headerDragOffsetX: CGFloat = 0
    @State private var isCommittingDateSwipe: Bool = false

    // Full-screen celebration state.
    @State private var showTickRain: Bool = false
    
    var selectedDateItems: [PriorityItem] {
        // Use allAssignedItems to ensure SwiftUI detects changes
        let calendar = Calendar.current
        return allAssignedItems.filter { item in
            guard let assignedDate = item.dateAssigned else { return false }
            return calendar.isDate(assignedDate, inSameDayAs: selectedDate)
        }.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    private func isToday(_ date: Date) -> Bool { Calendar.current.isDateInToday(date) }
    private func isYesterday(_ date: Date) -> Bool { Calendar.current.isDateInYesterday(date) }
    private func isTomorrow(_ date: Date) -> Bool { Calendar.current.isDateInTomorrow(date) }
    
    private func dayOffsetFromToday(for date: Date) -> Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let selectedStart = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: todayStart, to: selectedStart).day ?? 0
    }
    
    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    private func dayHeaderTitleText(for date: Date) -> String {
        if isToday(date) {
            return "Today's Mission"
        }
        if isYesterday(date) {
            return "Yesterday"
        }
        if isTomorrow(date) {
            return "Tomorrow"
        }
        
        let delta = dayOffsetFromToday(for: date)
        if delta < 0 {
            let n = abs(delta)
            return n == 1 ? "1 day ago" : "\(n) days ago"
        } else {
            let n = delta
            return n == 1 ? "1 day from now" : "\(n) days from now"
        }
    }
    
    private func dayHeaderSubtitleText(for date: Date) -> String? {
        return Self.monthDayFormatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.anchorBackground.ignoresSafeArea()
                
                if viewMode == .day {
                    dayView
                } else {
                    MonthlyView(
                        onDateSelected: { date in
                            withAnimation {
                                selectedDate = date
                                viewMode = .day
                            }
                        },
                        onSwitchToDayView: {
                            withAnimation {
                                viewMode = .day
                            }
                        }
                    )
                }
            }
            .tickRain(trigger: showTickRain)
        }
        .onAppear {
            // Enforce priority limits on app launch to recover from invalid states
            priorityManager.enforceAllPriorityLimits()
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // Enforce limit when switching dates
            priorityManager.enforcePriorityLimit(for: newValue)
        }
        .onChange(of: allAssignedItems) { oldValue, newValue in
            // Enforce limit when items change to catch any invalid states immediately
            priorityManager.enforcePriorityLimit(for: selectedDate)
        }
    }
    
    private var dayHeaderBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Menu {
                Button {
                    withAnimation {
                        selectedDate = Date()
                        viewMode = .day
                    }
                } label: {
                    Label("Today", systemImage: "sun.max")
                }
                
                Button {
                    withAnimation {
                        viewMode = .monthly
                    }
                } label: {
                    Label("Monthly View", systemImage: "calendar")
                }
                
                Button {
                    showFullScreenBacklog = true
                } label: {
                    Label("Backlog", systemImage: "tray")
                }
                
                Divider()
                
                if !calendarManager.isSignedIn {
                    Button {
                        handleProfileTap()
                    } label: {
                        Label("Sign In to Google Calendar", systemImage: "person.crop.circle")
                    }
                } else {
                    Button {
                        handleProfileTap()
                    } label: {
                        Label("Sign Out of Google Calendar", systemImage: "arrow.right.square")
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.anchorCardBg)
                    )
            }
            
            headerDateTitle
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var headerDateTitle: some View {
        let screenWidth = max(CGFloat(1), UIScreen.main.bounds.width)
        let dragX = max(-screenWidth, min(screenWidth, headerDragOffsetX))
        let progress = min(1.0, Double(abs(dragX) / screenWidth))
        
        let incomingDays: Int? = {
            if dragX > 0 { return -1 }     // swipe right -> previous day
            if dragX < 0 { return 1 }      // swipe left -> next day
            return nil
        }()
        
        let incomingDate: Date? = incomingDays.flatMap { days in
            Calendar.current.date(byAdding: .day, value: days, to: selectedDate)
        }
        
        return ZStack(alignment: .leading) {
            headerTitleStack(for: selectedDate)
                .opacity(1.0 - (progress * 0.45))
                .offset(x: dragX)
            
            if let incomingDate {
                headerTitleStack(for: incomingDate)
                    .opacity(progress)
                    .offset(x: dragX + (dragX >= 0 ? -screenWidth : screenWidth))
            }
        }
        // Keep the header from resizing as content slides.
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .accessibilityElement(children: .combine)
    }
    
    private func headerTitleStack(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dayHeaderTitleText(for: date))
                .anchorFont(.largeTitle, weight: .bold)
                .foregroundStyle(Color.anchorTextPrimary)
            
            if let subtitle = dayHeaderSubtitleText(for: date) {
                Text(subtitle)
                    .anchorFont(.caption, weight: .regular)
                    .foregroundStyle(Color.anchorTextSecondary)
            }
        }
    }
    
    private var dayView: some View {
        ZStack(alignment: .bottom) {
            // Swipe-to-navigate area (everything *except* the backlog panel).
            VStack(spacing: 0) {
                // Date nav / header (pinned to top)
                dayHeaderBar
                
                // The Anchor
                DailyPrioritiesView(
                    selectedDate: selectedDate,
                    backlogHeight: backlogVisibleHeight,
                    dateItems: Binding(
                        get: { selectedDateItems },
                        set: { _ in }
                    ),
                    onCelebrate: triggerTickRain
                )
                .padding(.top, 8)
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Critical: make the "empty" space in this area hit-testable so a drag can start
            // anywhere that isn't an interactive child view (cards/backlog).
            .contentShape(Rectangle())
            // Date navigation swipe.
            // Use `.gesture` (not `.simultaneousGesture`) so child drag gestures (e.g. task card swipe-to-complete)
            // take precedence and don't also trigger date changes.
            .gesture(dateSwipeGesture)
            
            // Backlog (pinned to bottom; excluded from date swipe hit area)
            BacklogView(
                showFullScreenBacklog: $showFullScreenBacklog,
                draftTitle: $backlogDraftTitle,
                requestFullScreenFocus: $backlogInputFocusRequested,
                selectedDate: selectedDate
            )
            .clipShape(TopRoundedRectangle(radius: 24))
            .onPreferenceChange(BacklogVisibleHeightPreferenceKey.self) { newValue in
                // Avoid noisy tiny changes; keep it stable for layout computations.
                if newValue > 0, abs(newValue - backlogVisibleHeight) > 0.5 {
                    backlogVisibleHeight = newValue
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .fullScreenCover(isPresented: $showFullScreenBacklog) {
            FullScreenBacklogView(
                draftTitle: $backlogDraftTitle,
                requestFocus: $backlogInputFocusRequested,
                selectedDate: $selectedDate
            )
        }
    }

    private func triggerTickRain() {
        // Restart the animation if it's already running.
        showTickRain = false
        DispatchQueue.main.async {
            showTickRain = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                showTickRain = false
            }
        }
    }

    private var dateSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 35)
            .onChanged { value in
                guard !isCommittingDateSwipe else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                headerDragOffsetX = value.translation.width
            }
            .onEnded { value in
                guard !isCommittingDateSwipe else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        headerDragOffsetX = 0
                    }
                    return
                }
                
                let threshold: CGFloat = 110
                let screenWidth = max(1, UIScreen.main.bounds.width)
                let endX = value.predictedEndTranslation.width
                let baseDate = selectedDate
                
                if endX > threshold {
                    // Swipe right -> previous day
                    isCommittingDateSwipe = true
                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.9)) {
                        headerDragOffsetX = screenWidth
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: baseDate) {
                            selectedDate = newDate
                        }
                        headerDragOffsetX = 0
                        isCommittingDateSwipe = false
                    }
                } else if endX < -threshold {
                    // Swipe left -> next day
                    isCommittingDateSwipe = true
                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.9)) {
                        headerDragOffsetX = -screenWidth
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: baseDate) {
                            selectedDate = newDate
                        }
                        headerDragOffsetX = 0
                        isCommittingDateSwipe = false
                    }
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        headerDragOffsetX = 0
                    }
                }
            }
    }
        
    func handleProfileTap() {
        if !calendarManager.isSignedIn {
            // Find root VC to present sign in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return }
            
            calendarManager.signIn(rootViewController: rootVC)
        } else {
            // Sign out - signOut() handles main thread safety internally
            calendarManager.signOut()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PriorityItem.self, configurations: config)
    let manager = PriorityManager(modelContext: container.mainContext)
    
    return AnchorMainView()
        .environment(manager)
        .environment(GoogleCalendarManager())
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
