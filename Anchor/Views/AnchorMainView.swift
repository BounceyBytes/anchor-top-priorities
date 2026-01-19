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
    
    // Swipe-to-navigate day paging state.
    // Tracks the user's finger so the current day's UI moves with the gesture.
    @State private var dayDragOffsetX: CGFloat = 0
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

    private func items(for date: Date) -> [PriorityItem] {
        let calendar = Calendar.current
        return allAssignedItems.filter { item in
            guard let assignedDate = item.dateAssigned else { return false }
            return calendar.isDate(assignedDate, inSameDayAs: date)
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
            // If yesterday (or earlier) has incomplete items, copy them into the backlog while keeping them visible on their original day.
            priorityManager.copyIncompletePastItemsToBacklogIfNeeded()
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // Enforce limit when switching dates
            priorityManager.enforcePriorityLimit(for: newValue)
            // If the date changes via any non-swipe path (tap, menu, monthly view),
            // make sure the swipe pager is visually reset.
            if !isCommittingDateSwipe {
                dayDragOffsetX = 0
            }
        }
        .onChange(of: allAssignedItems) { oldValue, newValue in
            // Enforce limit when items change to catch any invalid states immediately
            priorityManager.enforcePriorityLimit(for: selectedDate)
        }
    }
    
    private func dayHeaderBar(for date: Date, isInteractable: Bool) -> some View {
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
            
            headerDateTitle(displayedDate: date)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .allowsHitTesting(isInteractable)
    }

    private func headerDateTitle(displayedDate: Date) -> some View {
        StreakCirclesView(
            displayedDate: displayedDate,
            selectedDate: $selectedDate,
            priorityManager: priorityManager
        )
    }
    
    private var dayView: some View {
        ZStack(alignment: .bottom) {
            // Swipe-to-navigate area (everything *except* the backlog panel).
            daySwipePager
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

    private var daySwipePager: some View {
        GeometryReader { geo in
            let pageWidth = max(1, geo.size.width)
            let clampedDrag = max(-pageWidth, min(pageWidth, dayDragOffsetX))
            let baseOffset = -pageWidth // center the middle page (current day)

            HStack(spacing: 0) {
                dayPage(
                    date: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate,
                    isCurrent: false
                )
                .frame(width: pageWidth)

                dayPage(date: selectedDate, isCurrent: true)
                    .frame(width: pageWidth)

                dayPage(
                    date: Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate,
                    isCurrent: false
                )
                .frame(width: pageWidth)
            }
            .frame(width: pageWidth * 3, alignment: .leading)
            .offset(x: baseOffset + clampedDrag)
        }
    }

    private func dayPage(date: Date, isCurrent: Bool) -> some View {
        VStack(spacing: 0) {
            dayHeaderBar(
                for: date,
                isInteractable: isCurrent && !isCommittingDateSwipe && dayDragOffsetX == 0
            )

            DailyPrioritiesView(
                selectedDate: date,
                backlogHeight: backlogVisibleHeight,
                dateItems: Binding(
                    get: { items(for: date) },
                    set: { _ in }
                ),
                onCelebrate: triggerTickRain
            )
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        // Only the current page should be interactive; adjacent pages are visual during swipes.
        .allowsHitTesting(isCurrent && !isCommittingDateSwipe)
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
                dayDragOffsetX = value.translation.width
            }
            .onEnded { value in
                guard !isCommittingDateSwipe else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        dayDragOffsetX = 0
                    }
                    return
                }
                
                let screenWidth = max(1, UIScreen.main.bounds.width)
                let endX = value.predictedEndTranslation.width
                let baseDate = selectedDate
                let threshold: CGFloat = max(110, screenWidth * 0.22)
                
                if endX > threshold {
                    // Swipe right -> previous day
                    isCommittingDateSwipe = true
                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.9)) {
                        dayDragOffsetX = screenWidth
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                        let newDate = Calendar.current.date(byAdding: .day, value: -1, to: baseDate) ?? baseDate
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) {
                            selectedDate = newDate
                            dayDragOffsetX = 0
                            isCommittingDateSwipe = false
                        }
                    }
                } else if endX < -threshold {
                    // Swipe left -> next day
                    isCommittingDateSwipe = true
                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.9)) {
                        dayDragOffsetX = -screenWidth
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) {
                            selectedDate = newDate
                            dayDragOffsetX = 0
                            isCommittingDateSwipe = false
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        dayDragOffsetX = 0
                    }
                }
            }
    }
        
    func handleProfileTap() {
        if !calendarManager.isSignedIn {
            // Find the topmost presented view controller to avoid view hierarchy conflicts
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else { return }
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            calendarManager.signIn(rootViewController: topVC)
        } else {
            // Sign out - signOut() handles main thread safety internally
            calendarManager.signOut()
        }
    }
}

struct StreakCirclesView: View {
    let displayedDate: Date
    @Binding var selectedDate: Date
    let priorityManager: PriorityManager
    @Query(filter: #Predicate<PriorityItem> { $0.dateAssigned != nil }, sort: \.orderIndex)
    private var allAssignedItems: [PriorityItem]

    @State private var pulseScale: CGFloat = 1.0

    private let circleSize: CGFloat = 14
    private let circleSpacing: CGFloat = 10
    private let daysToShow: Int = 60 // 30 days past and 30 days future
    
    private static let streakDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private var calendar: Calendar {
        Calendar.current
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var dateRange: [Date] {
        // Center the range on the selected date, but don't go too far from today
        let centerDate = displayedDate
        let startDate = calendar.date(byAdding: .day, value: -daysToShow/2, to: centerDate) ?? centerDate
        var dates: [Date] = []
        for i in 0..<daysToShow {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                dates.append(calendar.startOfDay(for: date))
            }
        }
        return dates
    }
    
    private func prioritiesForDate(_ date: Date) -> [PriorityItem] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return allAssignedItems.filter { item in
            guard let assignedDate = item.dateAssigned else { return false }
            return assignedDate >= startOfDay && assignedDate < endOfDay
        }.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func isTop1Completed(for date: Date) -> Bool {
        let priorities = prioritiesForDate(date)
        return priorities.count > 0 && priorities[0].isCompleted
    }
    
    private func hasTop1Priority(for date: Date) -> Bool {
        return prioritiesForDate(date).count > 0
    }

    private func isCurrentDay(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    private func isYesterday(_ date: Date) -> Bool {
        calendar.isDateInYesterday(date)
    }
    
    private func isTomorrow(_ date: Date) -> Bool {
        calendar.isDateInTomorrow(date)
    }
    
    private func dateAnnotationText(for date: Date) -> String {
        if isCurrentDay(date) {
            return "Today"
        } else if isYesterday(date) {
            return "Yesterday"
        } else if isTomorrow(date) {
            return "Tomorrow"
        } else {
            return Self.streakDateFormatter.string(from: date)
        }
    }

    private func circleGradient(for date: Date) -> LinearGradient {
        let isCompleted = isTop1Completed(for: date)
        let isToday = isCurrentDay(date)
        let isFuture = date > today

        if isToday && !isCompleted {
            // Today: transparent fill (border and pulse make it visible)
            return LinearGradient(
                colors: [.clear, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isFuture && !isCompleted {
            // Future days: subtle neutral fill
            return LinearGradient(
                colors: [Color.white.opacity(0.2), Color.white.opacity(0.15)],
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
        let isSelected = calendar.isDate(date, inSameDayAs: displayedDate)
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
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let centerOffset = (geometry.size.width - circleSize) / 2

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: circleSpacing) {
                            ForEach(Array(dateRange.enumerated()), id: \.element) { index, date in
                                let isToday = isCurrentDay(date)
                                let isCompleted = isTop1Completed(for: date)
                                let hasPriority = hasTop1Priority(for: date)

                                Circle()
                                    .fill(circleGradient(for: date))
                                    .frame(width: circleSize, height: circleSize)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(circleBorderColor(for: date), lineWidth: circleBorderWidth(for: date))
                                    )
                                    .overlay {
                                        // Show checkmark for completed days
                                        if isCompleted {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                        // Show X for incomplete days (but not today or future days without completion)
                                        else if hasPriority && !isToday && date <= today {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 7, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
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
                        if let selectedIndex = dateRange.firstIndex(where: { calendar.isDate($0, inSameDayAs: displayedDate) }) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(selectedIndex, anchor: .center)
                                }
                            }
                        }
                    }
                    .onChange(of: displayedDate) { oldValue, newValue in
                        // Scroll to new displayed date (used during swipe paging).
                        if let newIndex = dateRange.firstIndex(where: { calendar.isDate($0, inSameDayAs: newValue) }) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            }
            .frame(height: circleSize + 4) // Add some vertical padding
            
            // Date annotation for selected date
            Text(dateAnnotationText(for: displayedDate))
                .anchorFont(.caption2, weight: .medium)
                .foregroundStyle(.secondary)
                .frame(height: 16)
        }
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
