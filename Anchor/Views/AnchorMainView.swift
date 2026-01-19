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
        StreakCirclesView(
            selectedDate: $selectedDate,
            priorityManager: priorityManager
        )
    }
    
    private var dayView: some View {
        ZStack(alignment: .bottom) {
            // Swipe-to-navigate area (everything *except* the backlog panel).
            VStack(spacing: 0) {
                // Date nav / header (pinned to top)
                dayHeaderBar

                // Daily progress bar
                DailyProgressBar(items: selectedDateItems)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

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

struct StreakCirclesView: View {
    @Binding var selectedDate: Date
    let priorityManager: PriorityManager

    @State private var pulseScale: CGFloat = 1.0

    private let circleSize: CGFloat = 14
    private let circleSpacing: CGFloat = 10
    private let daysToShow: Int = 60 // 30 days past and 30 days future

    private var calendar: Calendar {
        Calendar.current
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var dateRange: [Date] {
        // Center the range on the selected date, but don't go too far from today
        let centerDate = selectedDate
        let startDate = calendar.date(byAdding: .day, value: -daysToShow/2, to: centerDate) ?? centerDate
        var dates: [Date] = []
        for i in 0..<daysToShow {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                dates.append(calendar.startOfDay(for: date))
            }
        }
        return dates
    }

    private func isTop1Completed(for date: Date) -> Bool {
        let status = priorityManager.getCompletionStatus(for: date)
        return status.top1
    }

    private func isCurrentDay(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func circleGradient(for date: Date) -> LinearGradient {
        let isCompleted = isTop1Completed(for: date)
        let isToday = isCurrentDay(date)

        if isToday && !isCompleted {
            return LinearGradient(
                colors: [.clear, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isCompleted {
            return LinearGradient.streakGradient
        } else {
            return LinearGradient(
                colors: [Color.anchorStreakRed, Color.anchorStreakRed.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func circleBorderColor(for date: Date) -> Color {
        let isToday = isCurrentDay(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        if isSelected {
            return Color.white.opacity(0.9)
        } else if isToday {
            return Color.white.opacity(0.5)
        } else {
            return Color.clear
        }
    }

    private func circleBorderWidth(for date: Date) -> CGFloat {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = isCurrentDay(date)
        if isSelected {
            return 2.5
        } else if isToday {
            return 2.0
        } else {
            return 0
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let centerOffset = (geometry.size.width - circleSize) / 2

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: circleSpacing) {
                        ForEach(Array(dateRange.enumerated()), id: \.element) { index, date in
                            let isToday = isCurrentDay(date)
                            let isCompleted = isTop1Completed(for: date)

                            Circle()
                                .fill(circleGradient(for: date))
                                .frame(width: circleSize, height: circleSize)
                                .overlay(
                                    Circle()
                                        .strokeBorder(circleBorderColor(for: date), lineWidth: circleBorderWidth(for: date))
                                )
                                .overlay(
                                    // Add glow effect for completed circles
                                    Group {
                                        if isCompleted {
                                            Circle()
                                                .stroke(Color.anchorStreakGreen.opacity(0.3), lineWidth: 2)
                                                .blur(radius: 2)
                                        }
                                    }
                                )
                                .scaleEffect(isToday && !isCompleted ? pulseScale : 1.0)
                                .shadow(
                                    color: isCompleted ? Color.anchorStreakGreen.opacity(0.4) :
                                           isToday ? Color.white.opacity(0.2) : .clear,
                                    radius: isCompleted ? 4 : 2,
                                    x: 0,
                                    y: 0
                                )
                                .id(index)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedDate = date
                                        proxy.scrollTo(index, anchor: .center)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, centerOffset)
                }
                .onAppear {
                    // Start pulse animation for today
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        pulseScale = 1.3
                    }

                    // Scroll to selected date on appear
                    if let selectedIndex = dateRange.firstIndex(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(selectedIndex, anchor: .center)
                            }
                        }
                    }
                }
                .onChange(of: selectedDate) { oldValue, newValue in
                    // Scroll to new selected date
                    if let newIndex = dateRange.firstIndex(where: { calendar.isDate($0, inSameDayAs: newValue) }) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(height: circleSize + 4) // Add some vertical padding
    }
}

struct DailyProgressBar: View {
    let items: [PriorityItem]

    private var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    private var totalCount: Int {
        min(items.count, 3) // Max 3 priorities per day
    }

    private var progressPercentage: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(completedCount) / CGFloat(totalCount)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.anchorStreakGreen,
                                    Color.anchorStreakTeal
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                        .shadow(color: Color.anchorStreakGreen.opacity(0.5), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 8)

            // Progress text
            if totalCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: completedCount == totalCount ? "checkmark.circle.fill" : "circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            completedCount == totalCount ?
                                Color.anchorStreakGreen :
                                Color.white.opacity(0.5)
                        )

                    Text("\(completedCount) of \(totalCount) priorities completed")
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: completedCount)
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
