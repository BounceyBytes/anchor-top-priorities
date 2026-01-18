import SwiftUI

struct SchedulingSheet: View {
    let itemToSchedule: PriorityItem
    @Environment(GoogleCalendarManager.self) private var calendarManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedDate = Date()
    @State private var durationMinutes = 60
    @State private var dayEvents: [GoogleCalendarManager.DayEvent] = []
    @State private var isLoadingDay = false
    @State private var hasUserAdjustedTime = false
    @State private var sheetDetent: PresentationDetent = .large
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    if !calendarManager.isSignedIn {
                        ContentUnavailableView(
                            "Sign In Required",
                            systemImage: "calendar",
                            description: Text("Please sign in to Google Calendar to schedule your priorities.")
                        )

                        VStack(spacing: 12) {
                            Button("Sign In with Google") {
                                guard let scenes = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                      let root = scenes.windows.first?.rootViewController else { return }
                                calendarManager.signIn(rootViewController: root)
                            }
                            .foregroundColor(.white)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.anchorCoral)
                            )

                            Button("Cancel") {
                                dismiss()
                            }
                            .foregroundColor(.white)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                header

                                if isLoadingDay {
                                    ProgressView("Loading today's calendar…")
                                        .tint(.white)
                                        .foregroundColor(.white)
                                        .padding(.top, 8)
                                }

                                DayTimelineView(
                                    dayDate: today,
                                    events: visibleDayEvents,
                                    taskTitle: itemToSchedule.title,
                                    startTime: $selectedDate,
                                    durationMinutes: $durationMinutes,
                                    onUserAdjusted: {
                                        hasUserAdjustedTime = true
                                    }
                                )
                                .padding(.horizontal)

                                Text("Drag the block (or handle) to change start time. Snaps to 15-minute increments.")
                                    .anchorFont(.caption, weight: .semibold)
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                if isConflicting {
                                    Label("Conflicts with an existing calendar event", systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .anchorFont(.caption, weight: .semibold)
                                        .padding(.horizontal)
                                }

                                Button("Schedule Event") {
                                    scheduleItem()
                                }
                                .foregroundColor(.white)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isConflicting ? Color.gray.opacity(0.3) : Color.anchorCoral)
                                )
                                .disabled(isConflicting)
                                .padding(.horizontal)
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Schedule Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            sheetDetent = .large
            if calendarManager.isSignedIn {
                // Initialize to today; we'll pick the first free slot once events load.
                selectedDate = snapToTodayAnd15Minutes(Date(), rounding: .ceiling)
                loadDayAndDefaultIfNeeded(forceDefault: true)
            }
        }
        .onChange(of: calendarManager.isSignedIn) { oldValue, newValue in
            if newValue {
                sheetDetent = .large
                selectedDate = snapToTodayAnd15Minutes(Date(), rounding: .ceiling)
                loadDayAndDefaultIfNeeded(forceDefault: true)
            }
        }
    }
    
    private var today: Date { Date() }
    
    private var header: some View {
        VStack(spacing: 6) {
            Text("Schedule time today to")
                .anchorFont(.title3, weight: .semibold)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Text(itemToSchedule.title)
                .anchorFont(.title3, weight: .bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private var visibleDayEvents: [GoogleCalendarManager.DayEvent] {
        if let id = itemToSchedule.calendarEventId {
            return dayEvents.filter { $0.id != id }
        }
        return dayEvents
    }
    
    private var isConflicting: Bool {
        let duration = TimeInterval(durationMinutes * 60)
        let interval = DateInterval(start: selectedDate, end: selectedDate.addingTimeInterval(duration))
        return visibleDayEvents.contains { event in
            DateInterval(start: event.start, end: event.end).intersects(interval)
        }
    }
    
    private enum SnapRounding {
        case nearest
        case ceiling
    }
    
    private func snapToTodayAnd15Minutes(_ date: Date, rounding: SnapRounding) -> Date {
        let cal = Calendar.current
        let baseDay = cal.startOfDay(for: today)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: baseDay) ?? baseDay.addingTimeInterval(24 * 3600)
        
        // Force the date onto today.
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        var snappedMinute: Int
        
        switch rounding {
        case .nearest:
            snappedMinute = Int((Double(minute) / 15.0).rounded() * 15.0)
            if snappedMinute == 60 {
                snappedMinute = 0
                // roll hour; if over 23 we clamp below
                let rolled = cal.date(bySettingHour: min(hour + 1, 23), minute: snappedMinute, second: 0, of: baseDay) ?? baseDay
                return min(max(rolled, baseDay), endOfDay.addingTimeInterval(-60))
            }
        case .ceiling:
            snappedMinute = ((minute + 14) / 15) * 15
            if snappedMinute == 60 {
                snappedMinute = 0
                let rolled = cal.date(bySettingHour: min(hour + 1, 23), minute: snappedMinute, second: 0, of: baseDay) ?? baseDay
                return min(max(rolled, baseDay), endOfDay.addingTimeInterval(-60))
            }
        }
        
        let snapped = cal.date(bySettingHour: min(max(hour, 0), 23), minute: snappedMinute, second: 0, of: baseDay) ?? baseDay
        return min(max(snapped, baseDay), endOfDay.addingTimeInterval(-60))
    }
    
    private func firstAvailableStartTime(
        durationMinutes: Int,
        events: [GoogleCalendarManager.DayEvent]
    ) -> Date? {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: today)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(24 * 3600)
        
        let duration = TimeInterval(durationMinutes * 60)

        // We show the timeline starting at 6am; default suggestions should feel "early" too.
        let earliest = cal.date(bySettingHour: 6, minute: 0, second: 0, of: startOfDay) ?? startOfDay

        // Don't suggest a time in the past for today.
        let nowAligned = snapToTodayAnd15Minutes(Date(), rounding: .ceiling)
        var candidate = snapToTodayAnd15Minutes(max(earliest, nowAligned), rounding: .nearest)

        // Consider only timed events for slot finding (all-day events often shouldn't block a specific hour).
        let timedEvents = events.filter { !$0.isAllDay }.sorted { $0.start < $1.start }

        // Merge overlapping busy intervals.
        var mergedBusy: [DateInterval] = []
        mergedBusy.reserveCapacity(timedEvents.count)
        for ev in timedEvents {
            let interval = DateInterval(start: ev.start, end: ev.end)
            if let last = mergedBusy.last, last.end > interval.start || last.end == interval.start {
                mergedBusy[mergedBusy.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                mergedBusy.append(interval)
            }
        }

        for busy in mergedBusy {
            // Clamp busy interval to today's window.
            let busyStart = max(busy.start, startOfDay)
            let busyEnd = min(busy.end, endOfDay)
            guard busyEnd > busyStart else { continue }

            // If the candidate fits before the next busy block, take it.
            if candidate.addingTimeInterval(duration) <= busyStart {
                return candidate
            }

            // Otherwise, jump to the end of this busy block (aligned to 15m) and continue.
            if candidate < busyEnd {
                candidate = snapToTodayAnd15Minutes(busyEnd, rounding: .ceiling)
            }
        }

        // After the last busy block.
        if candidate.addingTimeInterval(duration) <= endOfDay {
            return candidate
        }
        return nil
    }
    
    private func loadDayAndDefaultIfNeeded(forceDefault: Bool) {
        isLoadingDay = true
        let duration = durationMinutes
        let day = today
        
        calendarManager.fetchDayEvents(for: day) { result in
            DispatchQueue.main.async {
                isLoadingDay = false
                switch result {
                case .success(let events):
                    dayEvents = events
                    if forceDefault || !hasUserAdjustedTime {
                        if let first = firstAvailableStartTime(durationMinutes: duration, events: visibleDayEvents) {
                            selectedDate = snapToTodayAnd15Minutes(first, rounding: .ceiling)
                        } else {
                            selectedDate = snapToTodayAnd15Minutes(Date(), rounding: .ceiling)
                        }
                    } else {
                        selectedDate = snapToTodayAnd15Minutes(selectedDate, rounding: .nearest)
                    }
                case .failure(let error):
                    print("Error fetching day events: \(error)")
                    dayEvents = []
                    if forceDefault || !hasUserAdjustedTime {
                        selectedDate = snapToTodayAnd15Minutes(Date(), rounding: .ceiling)
                    }
                }
            }
        }
    }
    
    func scheduleItem() {
        calendarManager.scheduleEvent(title: itemToSchedule.title, startTime: selectedDate, durationMinutes: durationMinutes) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let eventId):
                    itemToSchedule.calendarEventId = eventId
                    itemToSchedule.calendarEventStartTime = selectedDate
                    try? modelContext.save()
                    dismiss()
                case .failure(let error):
                    print("Error scheduling: \(error)")
                }
            }
        }
    }
}

private struct DayTimelineView: View {
    let dayDate: Date
    let events: [GoogleCalendarManager.DayEvent]
    let taskTitle: String
    @Binding var startTime: Date
    @Binding var durationMinutes: Int
    let onUserAdjusted: () -> Void
    
    private let endHour = 23
    private let hourHeight: CGFloat = 64
    private let leftGutter: CGFloat = 54
    private let snapMinutes: Int = 15
    private let minDurationMinutes: Int = 15
    private let maxDurationMinutes: Int = 240
    
    @State private var dragBaseMinutes: Int?
    @State private var handleDragBaseMinutes: Int?
    @State private var isInteracting: Bool = false
    
    var body: some View {
        let startHour = timelineStartHour
        // We render startHour...endHour inclusive, so match that height for consistent offsets.
        let rangeMinutes = (endHour - startHour + 1) * 60
        let totalHeight = CGFloat(rangeMinutes) * (hourHeight / 60.0)
        
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    timelineGrid(totalHeight: totalHeight)
                    busyBlocks(totalHeight: totalHeight)
                    currentTimeIndicator(totalHeight: totalHeight)
                    taskBlock(totalHeight: totalHeight)
                }
                .frame(height: totalHeight)
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .onAppear {
                clampStartTimeIfNeeded()
                scrollToStartTime(proxy, animated: false)
            }
            .onChange(of: startTime) { _, _ in
                clampStartTimeIfNeeded()
            }
            .onChange(of: isInteracting) { _, newValue in
                if newValue == false {
                    scrollToStartTime(proxy, animated: true)
                }
            }
        }
    }
    
    private var baseStartHour: Int { 6 }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(dayDate)
    }
    
    private var minAllowedStartTime: Date? {
        guard isToday else { return nil }
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        
        let snappedMinute = ((minute + (snapMinutes - 1)) / snapMinutes) * snapMinutes
        if snappedMinute >= 60 {
            let rolledHour = min(hour + 1, 23)
            return cal.date(bySettingHour: rolledHour, minute: 0, second: 0, of: cal.startOfDay(for: dayDate))
        }
        return cal.date(bySettingHour: min(max(hour, 0), 23), minute: snappedMinute, second: 0, of: cal.startOfDay(for: dayDate))
    }
    
    private var timelineStartHour: Int {
        guard let minAllowedStartTime else { return baseStartHour }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: minAllowedStartTime)
        return max(baseStartHour, min(hour, endHour))
    }
    
    private func minutesSinceTimelineStart(_ date: Date) -> Int {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: dayDate)
        let timelineStart = cal.date(bySettingHour: timelineStartHour, minute: 0, second: 0, of: dayStart) ?? dayStart
        let delta = date.timeIntervalSince(timelineStart)
        return max(0, Int(delta / 60.0))
    }
    
    private func yOffset(forMinutes minutes: Int) -> CGFloat {
        CGFloat(minutes) * (hourHeight / 60.0)
    }
    
    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
    
    private func snappedDate(forDragY y: CGFloat, totalHeight: CGFloat) -> Date {
        let cal = Calendar.current
        let clampedY = clamp(y, min: 0, max: totalHeight)
        let minutesFromStart = Int((clampedY / (hourHeight / 60.0)).rounded())
        let snappedMinutes = Int((Double(minutesFromStart) / Double(snapMinutes)).rounded() * Double(snapMinutes))

        let dayStart = cal.startOfDay(for: dayDate)
        let timelineStart = cal.date(bySettingHour: timelineStartHour, minute: 0, second: 0, of: dayStart) ?? dayStart
        let proposed = timelineStart.addingTimeInterval(TimeInterval(snappedMinutes * 60))
        return clampStartTime(proposed)
    }
    
    private func clampStartTime(_ date: Date) -> Date {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: dayDate)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
        let latest = dayEnd.addingTimeInterval(TimeInterval(-durationMinutes * 60))
        
        var out = date
        if let minAllowedStartTime {
            out = max(out, minAllowedStartTime)
        }
        out = min(out, latest)
        return out
    }
    
    private func clampStartTimeIfNeeded() {
        let clamped = clampStartTime(startTime)
        if clamped != startTime {
            startTime = clamped
        }
    }
    
    private func scrollToStartTime(_ proxy: ScrollViewProxy, animated: Bool) {
        let cal = Calendar.current
        let targetHour = min(max(cal.component(.hour, from: startTime), timelineStartHour), endHour)
        let action = {
            proxy.scrollTo(targetHour, anchor: .top)
        }
        // Defer to next runloop so the IDs exist.
        DispatchQueue.main.async {
            if animated {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    action()
                }
            } else {
                action()
            }
        }
    }
    
    private var taskInterval: DateInterval {
        DateInterval(start: startTime, end: startTime.addingTimeInterval(TimeInterval(durationMinutes * 60)))
    }
    
    private var isConflicting: Bool {
        events.contains { DateInterval(start: $0.start, end: $0.end).intersects(taskInterval) }
    }
    
    @ViewBuilder
    private func timelineGrid(totalHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(timelineStartHour...endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 10) {
                    Text(hourLabel(hour))
                        .anchorFont(.caption, weight: .semibold)
                        .foregroundStyle(Color.white.opacity(0.5))
                        .frame(width: leftGutter - 10, alignment: .trailing)
                        .padding(.top, -6)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                                .offset(y: hourHeight / 2)
                        }
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func hourLabel(_ hour: Int) -> String {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: dayDate)
        let d = cal.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart) ?? dayStart
        return d.formatted(date: .omitted, time: .shortened)
    }
    
    @ViewBuilder
    private func busyBlocks(totalHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let timedEvents = events.filter { !$0.isAllDay }
            let laidOut = layoutOverlappingEvents(timedEvents)
            
            ForEach(laidOut) { entry in
                let event = entry.event
                let startMinutes = minutesSinceTimelineStart(event.start)
                let endMinutes = minutesSinceTimelineStart(event.end)
                let y = yOffset(forMinutes: startMinutes)
                let height = max(18, yOffset(forMinutes: max(0, endMinutes - startMinutes)))
                
                let laneSpacing: CGFloat = 8
                let contentWidth = max(1, geo.size.width - leftGutter)
                let columns = max(1, entry.columnCount)
                let laneWidth = (contentWidth - laneSpacing * CGFloat(columns - 1)) / CGFloat(columns)
                let x = leftGutter + CGFloat(entry.column) * (laneWidth + laneSpacing)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        Text(event.title)
                            .anchorFont(.caption, weight: .semibold)
                            .foregroundStyle(Color.white.opacity(0.8))
                            .lineLimit(2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .frame(width: laneWidth, height: height, alignment: .topLeading)
                    .offset(x: x, y: y)
                    .allowsHitTesting(false)
            }
        }
    }
    
    private struct LaidOutEvent: Identifiable {
        let event: GoogleCalendarManager.DayEvent
        let column: Int
        let columnCount: Int
        var id: String { event.id }
    }
    
    /// Assigns overlapping events into non-overlapping "lanes" (columns) like a real calendar.
    private func layoutOverlappingEvents(_ events: [GoogleCalendarManager.DayEvent]) -> [LaidOutEvent] {
        let sorted = events
            .filter { $0.end > $0.start }
            .sorted {
                if $0.start == $1.start { return $0.end < $1.end }
                return $0.start < $1.start
            }
        
        // Partition into overlap groups so columnCount is local to each cluster.
        var groups: [[GoogleCalendarManager.DayEvent]] = []
        var current: [GoogleCalendarManager.DayEvent] = []
        var currentEnd: Date?
        
        for ev in sorted {
            if current.isEmpty {
                current = [ev]
                currentEnd = ev.end
                continue
            }
            
            if let end = currentEnd, ev.start < end {
                current.append(ev)
                currentEnd = max(end, ev.end)
            } else {
                groups.append(current)
                current = [ev]
                currentEnd = ev.end
            }
        }
        if !current.isEmpty {
            groups.append(current)
        }
        
        var out: [LaidOutEvent] = []
        out.reserveCapacity(sorted.count)
        
        for group in groups {
            var laneEnds: [Date] = []
            var staged: [(event: GoogleCalendarManager.DayEvent, column: Int)] = []
            staged.reserveCapacity(group.count)
            
            for ev in group {
                // Find the first lane that's free.
                if let idx = laneEnds.firstIndex(where: { $0 <= ev.start }) {
                    laneEnds[idx] = ev.end
                    staged.append((ev, idx))
                } else {
                    laneEnds.append(ev.end)
                    staged.append((ev, laneEnds.count - 1))
                }
            }
            
            let columnCount = max(1, laneEnds.count)
            out.append(contentsOf: staged.map { LaidOutEvent(event: $0.event, column: $0.column, columnCount: columnCount) })
        }
        
        return out
    }
    
    @ViewBuilder
    private func currentTimeIndicator(totalHeight: CGFloat) -> some View {
        if Calendar.current.isDateInToday(dayDate) {
            let now = Date()
            let minutes = minutesSinceTimelineStart(now)
            let y = yOffset(forMinutes: minutes)
            
            HStack(spacing: 10) {
                Color.clear.frame(width: leftGutter - 10)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.anchorIndigo)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(Color.anchorIndigo.opacity(0.9))
                        .frame(height: 2)
                }
            }
            .offset(y: clamp(y, min: 0, max: totalHeight))
            .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private func taskBlock(totalHeight: CGFloat) -> some View {
        let startMinutes = minutesSinceTimelineStart(startTime)
        let y = yOffset(forMinutes: startMinutes)
        let height = yOffset(forMinutes: durationMinutes)
        let endTime = startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
        
        HStack(spacing: 10) {
            Color.clear.frame(width: leftGutter - 10)
            
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.anchorCoral,
                            Color.anchorCoral.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isConflicting ? Color.orange.opacity(0.9) : Color.white.opacity(0.2), lineWidth: isConflicting ? 2.5 : 1.5)
                )
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(taskTitle)
                            .anchorFont(.headline, weight: .bold)
                            .lineLimit(2)
                        Text("\(startTime.formatted(date: .omitted, time: .shortened)) – \(endTime.formatted(date: .omitted, time: .shortened))")
                            .anchorFont(.caption, weight: .semibold)
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .overlay(alignment: .bottomTrailing) {
                    // Resize handle
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 46, height: 20)
                        .overlay {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .padding(10)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    onUserAdjusted()
                                    isInteracting = true
                                    // Move the event while keeping duration constant.
                                    if handleDragBaseMinutes == nil {
                                        handleDragBaseMinutes = startMinutes
                                    }
                                    let baseY = yOffset(forMinutes: handleDragBaseMinutes ?? startMinutes)
                                    let newY = clamp(baseY + value.translation.height, min: 0, max: totalHeight - height)
                                    startTime = snappedDate(forDragY: newY, totalHeight: totalHeight)
                                }
                                .onEnded { _ in
                                    handleDragBaseMinutes = nil
                                    isInteracting = false
                                }
                        )
                }
                .frame(height: max(40, height))
                .contentShape(RoundedRectangle(cornerRadius: 14))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            onUserAdjusted()
                            isInteracting = true
                            if dragBaseMinutes == nil {
                                dragBaseMinutes = startMinutes
                            }
                            let baseY = yOffset(forMinutes: dragBaseMinutes ?? startMinutes)
                            let newY = clamp(baseY + value.translation.height, min: 0, max: totalHeight - height)
                            startTime = snappedDate(forDragY: newY, totalHeight: totalHeight)
                        }
                        .onEnded { _ in
                            dragBaseMinutes = nil
                            isInteracting = false
                        }
                )
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(y: clamp(y, min: 0, max: totalHeight - height))
    }
}
