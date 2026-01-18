import SwiftUI
import SwiftData

struct DailyPrioritiesView: View {
    @Environment(PriorityManager.self) private var priorityManager
    @Environment(AchievementManager.self) private var achievementManager
    @Environment(GoogleCalendarManager.self) private var calendarManager
    let selectedDate: Date
    let backlogHeight: CGFloat
    @Binding var dateItems: [PriorityItem]
    let onCelebrate: () -> Void
    
    @State private var newItemTitle = ""
    @State private var isAddingTask = false
    @State private var draggedItem: PriorityItem?
    @State private var dragOffset: CGSize = .zero
    @State private var pomodoroTimer = PomodoroTimer()
    @State private var showPomodoroTimer = false
    @State private var showSchedulingSheet = false
    @State private var schedulingItem: PriorityItem?
    @State private var editingItemId: UUID?
    @State private var showLimitAlert = false
    @State private var limitAlertMessage = ""
    
    let slotColors: [Color] = [.anchorCoral, .anchorCoral, .anchorCoral]
    // Keep spacing proportional to the card height for consistent visual rhythm.
    // Requested: spacing between cards = 1/4 of the card height.
    private let slotMinHeight: CGFloat = 126
    private var slotSpacing: CGFloat { slotMinHeight / 4 }
    private let listHorizontalPadding: CGFloat = 16
    private let swipeAffordanceThreshold: CGFloat = 100
    private let swipeAffordanceMinDistance: CGFloat = 12
    
    private func slotMinHeight(for priorityNumber: Int) -> CGFloat {
        // Keep the 3 slots the same height so the vertical rhythm (and perceived "gap" between cards)
        // is consistent.
        slotMinHeight
    }
    
    var body: some View {
        VStack(spacing: slotSpacing) {
            // Show filled priorities with drag and drop
            ForEach(Array(dateItems.enumerated()), id: \.element.id) { index, item in
                let isActiveDrag = draggedItem?.id == item.id
                PrioritySlotCard(
                    item: item,
                    priorityNumber: index + 1,
                    color: slotColors[index % slotColors.count],
                    editingItemId: $editingItemId,
                    onCelebrate: onCelebrate,
                    onComplete: { handleCompletion(item, index: index) },
                    onPunt: {
                        do {
                            try priorityManager.puntToTomorrow(item)
                        } catch {
                            limitAlertMessage = error.localizedDescription
                            showLimitAlert = true
                        }
                    },
                    onPomodoro: {
                        pomodoroTimer.start(for: item.title)
                        showPomodoroTimer = true
                    },
                    onSchedule: {
                        schedulingItem = item
                        showSchedulingSheet = true
                    },
                    onDelete: { priorityManager.deletePriority(item) },
                    onRename: { newTitle in
                        priorityManager.renamePriority(item, to: newTitle)
                    },
                    onMoveToBacklog: { priorityManager.moveToBacklog(item) }
                )
                .frame(maxWidth: .infinity, minHeight: slotMinHeight(for: index + 1), alignment: .top)
                .opacity(isActiveDrag ? 0.6 : 1.0)
                .scaleEffect(isActiveDrag ? 1.05 : 1.0)
                .offset(isActiveDrag ? dragOffset : .zero)
                .shadow(color: isActiveDrag ? .black.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
                .zIndex(isActiveDrag ? 1 : 0)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            if draggedItem == nil {
                                draggedItem = item
                                // Haptic feedback when drag starts
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            handleSwipeEnd(value: value, item: item, index: index)
                        }
                )
            }
            
            // Show empty slots only if we have fewer than 3 priorities
            if dateItems.count < 3 {
                ForEach(dateItems.count..<3, id: \.self) { index in
                    if isAddingTask && index == dateItems.count {
                        // Inline task entry
                        InlineTaskEntryCard(
                            priorityNumber: index + 1,
                            color: slotColors[index],
                            text: $newItemTitle,
                            onSubmit: {
                                let trimmedTitle = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmedTitle.isEmpty {
                                    do {
                                        try priorityManager.addPriority(
                                            title: trimmedTitle,
                                            toBacklog: false,
                                            for: selectedDate
                                        )
                                        newItemTitle = ""
                                        isAddingTask = false
                                    } catch {
                                        limitAlertMessage = error.localizedDescription
                                        showLimitAlert = true
                                        // Keep the task in the input field so user can try again or cancel
                                    }
                                }
                            },
                            onCancel: {
                                newItemTitle = ""
                                isAddingTask = false
                            }
                        )
                        .frame(maxWidth: .infinity, minHeight: slotMinHeight(for: index + 1), alignment: .top)
                    } else {
                        EmptySlotCard(priorityNumber: index + 1, color: slotColors[index])
                            .frame(maxWidth: .infinity, minHeight: slotMinHeight(for: index + 1), alignment: .top)
                            .onTapGesture {
                                isAddingTask = true
                            }
                    }
                }
            }
        }
        .padding(.horizontal, listHorizontalPadding)
        .overlay(alignment: .topLeading) {
            // Swipe affordance overlay at VStack level to extend to screen edges
            if draggedItem != nil {
                SwipeAffordanceOverlay(
                    translation: dragOffset,
                    threshold: swipeAffordanceThreshold,
                    minDistance: swipeAffordanceMinDistance,
                    backlogHeight: backlogHeight
                )
                .frame(width: UIScreen.main.bounds.width, alignment: .topLeading)
                .allowsHitTesting(false)
            }
        }
        .fullScreenCover(isPresented: $showPomodoroTimer) {
            PomodoroTimerView(timer: pomodoroTimer)
        }
        .sheet(isPresented: $showSchedulingSheet) {
            if let item = schedulingItem {
                SchedulingSheet(itemToSchedule: item)
            }
        }
        .alert("Cannot Add Task", isPresented: $showLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(limitAlertMessage)
        }
    }

    private func handleCompletion(_ item: PriorityItem, index: Int) {
        // Toggle completion
        priorityManager.toggleCompletion(item)

        // If this is Priority #1 and we're marking it complete (and it's today), check for achievements
        if index == 0 && item.isCompleted && Calendar.current.isDateInToday(selectedDate) {
            let currentStreak = priorityManager.calculateCurrentStreak()

            // Update stats
            let allComplete = dateItems.count == 3 && dateItems.allSatisfy { $0.isCompleted }
            achievementManager.updateStats(
                currentStreak: currentStreak,
                top1Completed: true,
                allCompleted: allComplete
            )

            // Check for new achievements
            achievementManager.checkAndAwardAchievements(for: currentStreak)

            // Enhanced haptic for #1 completion
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
        }
    }

    private func handleSwipeEnd(value: DragGesture.Value, item: PriorityItem, index: Int) {
        let horizontalSwipe = abs(value.translation.width) > abs(value.translation.height)
        let swipeThreshold: CGFloat = swipeAffordanceThreshold
        
        if horizontalSwipe {
            // Horizontal swipe - mark as completed/uncompleted
            if value.translation.width > swipeThreshold {
                // Swipe right - mark as completed
                if !item.isCompleted {
                    handleCompletion(item, index: index)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } else if value.translation.width < -swipeThreshold {
                // Swipe left - mark as uncompleted
                if item.isCompleted {
                    handleCompletion(item, index: index)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } else {
            // Vertical drag - reorder priorities
            let dragDistance = value.translation.height
            let newIndex = reorderedIndex(from: index, dragDistance: dragDistance)
            
            if newIndex != index {
                var reorderedItems = dateItems
                reorderedItems.remove(at: index)
                reorderedItems.insert(item, at: newIndex)
                priorityManager.reorderPriorities(reorderedItems)
                
                // Haptic feedback for successful reorder
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
        
        // Reset drag state with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = .zero
            draggedItem = nil
        }
    }
    
    private func reorderedIndex(from index: Int, dragDistance: CGFloat) -> Int {
        guard dateItems.count > 1 else { return index }
        
        var target = index
        
        if dragDistance > 0 {
            var remaining = dragDistance
            while target < dateItems.count - 1 {
                // Threshold to move down one slot: cross midpoint between current and next card (+ spacing)
                let currentH = slotMinHeight(for: target + 1)
                let nextH = slotMinHeight(for: target + 2)
                let threshold = (currentH / 2) + slotSpacing + (nextH / 2)
                
                if remaining > threshold {
                    remaining -= threshold
                    target += 1
                } else {
                    break
                }
            }
        } else if dragDistance < 0 {
            var remaining = -dragDistance
            while target > 0 {
                // Threshold to move up one slot: cross midpoint between current and previous card (+ spacing)
                let currentH = slotMinHeight(for: target + 1)
                let prevH = slotMinHeight(for: target)
                let threshold = (currentH / 2) + slotSpacing + (prevH / 2)
                
                if remaining > threshold {
                    remaining -= threshold
                    target -= 1
                } else {
                    break
                }
            }
        }
        
        return target
    }
}

struct PrioritySlotCard: View {
    let item: PriorityItem
    let priorityNumber: Int
    let color: Color
    @Binding var editingItemId: UUID?
    let onCelebrate: () -> Void
    let onComplete: () -> Void
    let onPunt: () -> Void
    let onPomodoro: () -> Void
    let onSchedule: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onMoveToBacklog: () -> Void
    
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var inlineEditText = ""
    @State private var suppressCommitOnEnd = false
    @FocusState private var isInlineTitleFocused: Bool

    private var cardBackgroundColor: Color {
        item.isCompleted ? Color.anchorCompletedGreen.opacity(0.6) : color
    }
    
    private var primaryForegroundColor: Color {
        item.isCompleted ? .black.opacity(0.65) : .black
    }
    
    private var secondaryForegroundColor: Color {
        item.isCompleted ? .black.opacity(0.45) : .black.opacity(0.6)
    }
    
    private var isPrimary: Bool { priorityNumber == 1 }
    private var isSecondary: Bool { priorityNumber == 2 }
    private var isScheduled: Bool { item.calendarEventId != nil }
    private var isInlineEditing: Bool { editingItemId == item.id }
    
    private var badgeSize: CGFloat {
        isPrimary ? 40 : isSecondary ? 34 : 30
    }
    
    private static let unifiedTitleFont: Font.TextStyle = .title3
    private static let unifiedTitleWeight: Font.Weight = .semibold
    
    // Keep shadows visually consistent so the perceived gap between cards is consistent too.
    private var cardShadowColor: Color { 
        if item.isCompleted {
            return .black.opacity(0.05) // Much subtler shadow for completed tasks
        }
        return .black.opacity(isPrimary ? 0.16 : 0.12)
    }
    private var cardShadowRadius: CGFloat { item.isCompleted ? 4 : 10 }
    private var cardShadowYOffset: CGFloat { item.isCompleted ? 2 : 6 }

    private var scheduledHelperText: String? {
        guard isScheduled else { return nil }
        if let startTime = item.calendarEventStartTime {
            return "Scheduled • \(startTime.formatted(date: .omitted, time: .shortened))"
        }
        return "Scheduled"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Line 1: Priority number + task title
            HStack(alignment: .center, spacing: 10) {
                // Priority Number Badge with Crown for #1
                ZStack {
                    Text("\(priorityNumber)")
                        .anchorFont(.title2, weight: .bold)
                        .foregroundStyle(item.isCompleted ? .black.opacity(0.55) : .black.opacity(0.75))
                        .frame(width: badgeSize, height: badgeSize)
                        .background(
                            Circle()
                                .fill(item.isCompleted ? .white.opacity(0.3) : .white.opacity(0.45))
                        )

                    // Crown icon for Priority #1
                    if isPrimary && !item.isCompleted {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.yellow)
                            .offset(x: 14, y: -14)
                    }
                }
                
                if isInlineEditing {
                    HStack(spacing: 8) {
                        TextField("Task name", text: $inlineEditText)
                            .anchorFont(Self.unifiedTitleFont, weight: Self.unifiedTitleWeight)
                            .foregroundStyle(primaryForegroundColor)
                            .focused($isInlineTitleFocused)
                            .submitLabel(.done)
                            .onSubmit { commitInlineEdit(endEditing: true) }
                            .tint(primaryForegroundColor)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(.white.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        Button(action: { commitInlineEdit(endEditing: true) }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: cancelInlineEdit) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(item.title)
                        .anchorFont(Self.unifiedTitleFont, weight: Self.unifiedTitleWeight)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(primaryForegroundColor)
                        .lineLimit(isPrimary ? 3 : 2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Line 2: Action buttons
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if let scheduledText = scheduledHelperText {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                            
                            Text(scheduledText)
                                .anchorFont(.caption2, weight: .semibold)
                        }
                        .foregroundStyle(secondaryForegroundColor)
                        .lineLimit(1)
                    }
                    
                    if isPrimary && !item.isCompleted {
                        Text("Put all energy here!")
                            .anchorFont(.caption, weight: .semibold)
                            .foregroundStyle(.black.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: onPomodoro) {
                    Image(systemName: "timer")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(secondaryForegroundColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(item.isCompleted ? .white.opacity(0.2) : .white.opacity(0.3))
                        )
                }
                
                Button(action: onSchedule) {
                    Image(systemName: isScheduled ? "calendar.badge.checkmark" : "calendar")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(secondaryForegroundColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(item.isCompleted ? .white.opacity(0.2) : .white.opacity(0.3))
                        )
                }
                
                Menu {
                    Button(action: {
                        renameText = item.title
                        showRenameAlert = true
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(action: onMoveToBacklog) {
                        Label("Move to backlog", systemImage: "tray")
                    }
                    Button(action: onPunt) {
                        Label("Punt to Tomorrow", systemImage: "arrow.turn.up.right")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .padding(8)
                        .foregroundStyle(.black.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            ZStack {
                cardBackgroundColor
                if item.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 170, weight: .black))
                        .foregroundStyle(.white.opacity(0.12))
                        .rotationEffect(.degrees(-18))
                        .offset(x: 16, y: 6)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isPrimary && !item.isCompleted
                        ? Color.yellow.opacity(0.4)
                        : .white.opacity(item.isCompleted ? 0.25 : 0.55),
                    lineWidth: isPrimary && !item.isCompleted ? 3 : 2
                )
        )
        .cornerRadius(16)
        .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: cardShadowYOffset)
        .animation(.spring, value: item.isCompleted)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            guard !isInlineEditing else { return }
            editingItemId = item.id
        }
        .onChange(of: editingItemId) { oldValue, newValue in
            // If we were editing this card and selection moved elsewhere, commit without
            // mutating `editingItemId` (the new selection should win).
            if oldValue == item.id && newValue != item.id {
                if suppressCommitOnEnd {
                    suppressCommitOnEnd = false
                } else {
                    commitInlineEdit(endEditing: false)
                }
            }
            
            if newValue == item.id {
                inlineEditText = item.title
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isInlineTitleFocused = true
                }
            }
        }
        .onChange(of: isInlineTitleFocused) { oldValue, newValue in
            guard isInlineEditing else { return }
            if oldValue && !newValue {
                // Focus moved away => commit unless explicitly cancelled.
                commitInlineEdit(endEditing: true)
            }
        }
        .onChange(of: item.isCompleted) { oldValue, newValue in
            if newValue && !oldValue {
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)

                // Full-screen tick rain (owned by the parent view).
                onCelebrate()
            } else if !newValue && oldValue {
                // Light haptic for uncompleting
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
        .alert("Rename Task", isPresented: $showRenameAlert) {
            TextField("Task name", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameText = ""
            }
            Button("Rename") {
                if !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onRename(renameText.trimmingCharacters(in: .whitespacesAndNewlines))
                    renameText = ""
                }
            }
        }
    }
    
    private func commitInlineEdit(endEditing: Bool) {
        guard isInlineEditing || !endEditing else { return }
        let trimmed = inlineEditText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if endEditing {
            suppressCommitOnEnd = true
            isInlineTitleFocused = false
            editingItemId = nil
        }
        
        guard !trimmed.isEmpty else {
            inlineEditText = item.title
            return
        }
        
        if trimmed != item.title {
            onRename(trimmed)
        }
    }
    
    private func cancelInlineEdit() {
        guard isInlineEditing else { return }
        inlineEditText = ""
        // Keep editing mode active and focus on the text field
    }
}

private struct SwipeAffordanceOverlay: View {
    let translation: CGSize
    let threshold: CGFloat
    let minDistance: CGFloat
    let backlogHeight: CGFloat

    private func clamp(_ x: CGFloat, min mn: CGFloat, max mx: CGFloat) -> CGFloat {
        Swift.min(mx, Swift.max(mn, x))
    }

    private var isHorizontalSwipe: Bool {
        abs(translation.width) > abs(translation.height) && abs(translation.width) >= minDistance
    }

    private var rightProgress: CGFloat {
        guard isHorizontalSwipe else { return 0 }
        return clamp(translation.width / threshold, min: 0, max: 1)
    }

    private var leftProgress: CGFloat {
        guard isHorizontalSwipe else { return 0 }
        return clamp((-translation.width) / threshold, min: 0, max: 1)
    }

    var body: some View {
        GeometryReader { geo in
            let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            
            // Use the GeometryReader's actual size to determine available space
            // The overlay should extend to the full screen width and height (minus backlog)
            let safeAreaBottom = geo.safeAreaInsets.bottom
            let buffer: CGFloat = 8 // Small buffer to ensure arc stops just above backlog
            
            // Compute the backlog top in *global* coordinates, then convert to this overlay's local space.
            // This is important because this overlay does not start at y=0 of the screen (it sits below the header).
            let overlayTopYGlobal = geo.frame(in: .global).minY
            let backlogTopYGlobal = screenHeight - safeAreaBottom - backlogHeight
            let desiredHeight = backlogTopYGlobal - buffer - overlayTopYGlobal
            let availableHeight = max(0, min(desiredHeight, geo.size.height))
            
            ZStack {
                SideArcAffordance(
                    side: .right,
                    progress: rightProgress,
                    color: Color(red: 0.2, green: 0.9, blue: 0.3), // Vibrant green
                    systemImage: "checkmark",
                    screenWidth: screenWidth,
                    cardHeight: availableHeight
                )
                SideArcAffordance(
                    side: .left,
                    progress: leftProgress,
                    color: Color(red: 1.0, green: 0.85, blue: 0.0), // Vibrant yellow
                    systemImage: "arrow.uturn.left",
                    screenWidth: screenWidth,
                    cardHeight: availableHeight
                )
            }
            .frame(width: screenWidth, height: availableHeight, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.85), value: rightProgress)
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.85), value: leftProgress)
    }
}

private struct SideArcAffordance: View {
    enum Side { case left, right }

    let side: Side
    let progress: CGFloat
    let color: Color
    let systemImage: String
    let screenWidth: CGFloat
    let cardHeight: CGFloat

    private func clamp(_ x: CGFloat, min mn: CGFloat, max mx: CGFloat) -> CGFloat {
        Swift.min(mx, Swift.max(mn, x))
    }

    var body: some View {
        let h = cardHeight
        let w = screenWidth
        let t = clamp(progress, min: 0, max: 1)
        
        // Arc extends 30% of screen width at the middle
        let maxArcWidth = w * 0.3
        let currentArcWidth = maxArcWidth * t
        
        // Calculate the arc path
        let startX: CGFloat = (side == .right) ? w : 0
        let endX: CGFloat = (side == .right) ? w : 0
        let midX: CGFloat = (side == .right) ? (w - currentArcWidth) : currentArcWidth
        
        // Position icons at the screen edges, moving inward as progress increases
        let iconX: CGFloat = (side == .right) ? (w - 44 - currentArcWidth * 0.5) : (44 + currentArcWidth * 0.5)
        let iconOpacity = Double(clamp(0.15 + t * 0.95, min: 0, max: 1))

        ZStack {
            // Draw the arc shape using a Path
            // The arc curves from the top edge, inward 30% at the middle, then back to the bottom edge
            Path { path in
                // Start at top edge
                path.move(to: CGPoint(x: startX, y: 0))
                // Create a smooth curve using a single quadratic curve
                // Control point is positioned to create the 30% inward bulge at the middle
                path.addQuadCurve(
                    to: CGPoint(x: endX, y: h),
                    control: CGPoint(x: midX, y: h / 2)
                )
                // Close the path along the screen edge to create a filled arc shape
                path.addLine(to: CGPoint(x: (side == .right) ? w : 0, y: h))
                path.addLine(to: CGPoint(x: (side == .right) ? w : 0, y: 0))
                path.closeSubpath()
            }
            .fill(color)
            .opacity(Double(t))

            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
                .position(x: iconX, y: h / 2)
                .scaleEffect(0.88 + (0.14 * t))
                .opacity(iconOpacity)
        }
        .frame(width: w, height: h)
        .clipped()
    }
}

struct EmptySlotCard: View {
    let priorityNumber: Int
    let color: Color
    
    private var badgeSize: CGFloat {
        priorityNumber == 1 ? 40 : priorityNumber == 2 ? 34 : 30
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Line 1: Priority number + "Add Priority" text (matching PrioritySlotCard structure)
            HStack(alignment: .center, spacing: 10) {
                // Priority Number Badge
                Text("\(priorityNumber)")
                    .anchorFont(.title2, weight: .bold)
                    .foregroundStyle(color.opacity(0.7))
                    .frame(width: badgeSize, height: badgeSize)
                    .background(
                        Circle()
                            .fill(color.opacity(0.2))
                    )
                
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .foregroundStyle(color)
                    Text("Add Priority \(priorityNumber)")
                        .anchorFont(.title3, weight: .semibold)
                        .foregroundStyle(color.opacity(0.8))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Line 2: Empty space to match action buttons row in PrioritySlotCard
            HStack(spacing: 8) {
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
        )
        .contentShape(Rectangle())
    }
}

struct InlineTaskEntryCard: View {
    let priorityNumber: Int
    let color: Color
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority Number Badge
            Text("\(priorityNumber)")
                .anchorFont(.title2, weight: .bold)
                .foregroundStyle(color.opacity(0.7))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(color.opacity(0.2))
                )
            
            TextField("Task name", text: $text)
                .anchorFont(.title3, weight: .semibold)
                .foregroundStyle(.white)
                .focused($isFocused)
                .onSubmit {
                    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedText.isEmpty {
                        isFocused = false
                        onSubmit()
                    }
                }
                .submitLabel(.done)
                .tint(.white)
            
            Button(action: onSubmit) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(color)
                    )
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .foregroundStyle(.black.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.3))
                    )
            }
        }
        .padding()
        .background(color.opacity(0.3))
        .cornerRadius(16)
        .onAppear {
            isFocused = true
        }
    }
}
