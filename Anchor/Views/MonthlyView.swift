import SwiftUI
import SwiftData

struct MonthlyView: View {
    @Environment(PriorityManager.self) private var priorityManager
    @State private var currentMonth: Date = Date()
    var onDateSelected: ((Date) -> Void)?
    var onSwitchToDayView: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Menu {
                    Button {
                        onDateSelected?(Date())
                    } label: {
                        Label("Go to Today", systemImage: "calendar")
                    }
                    
                    Divider()
                    
                    Button {
                        onSwitchToDayView?()
                    } label: {
                        Label("Day View", systemImage: "square.grid.2x2")
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
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(monthsToShow, id: \.self) { month in
                            MonthCalendarView(month: month, onDateSelected: onDateSelected)
                                .padding(.bottom, 40)
                                .id(month)
                        }
                    }
                }
                .onAppear {
                    // Scroll to current month, centered vertically
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    if let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(currentMonthStart, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // Start from current month
            let calendar = Calendar.current
            let today = Date()
            if let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) {
                currentMonth = monthStart
            } else {
                currentMonth = calendar.startOfDay(for: today)
            }
        }
    }
    
    private var monthsToShow: [Date] {
        let calendar = Calendar.current
        var months: [Date] = []
        
        // Show 6 months before and 6 months after current month (13 months total)
        // This allows the current month to be centered
        for i in -6...6 {
            if let month = calendar.date(byAdding: .month, value: i, to: currentMonth) {
                if let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) {
                    months.append(monthStart)
                }
            }
        }
        
        return months
    }
}

struct MonthCalendarView: View {
    @Environment(PriorityManager.self) private var priorityManager
    let month: Date
    var onDateSelected: ((Date) -> Void)?
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }
    
    private var monthEnd: Date {
        calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? month
    }
    
    private var firstWeekday: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        // Convert to 0-based (Sunday = 0)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
    
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: month)?.count ?? 30
    }
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(monthName)
                .anchorFont(.title2, weight: .bold)
                .padding(.horizontal)
                .padding(.top, 20)
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .anchorFont(.caption, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                // Empty cells for days before month starts
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear
                        .frame(height: 60)
                }
                
                // Days of the month
                ForEach(1...daysInMonth, id: \.self) { day in
                    if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                        DayCellView(date: date, dayNumber: day, onDateSelected: onDateSelected)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortWeekdaySymbols
    }
}

struct DayCellView: View {
    @Environment(PriorityManager.self) private var priorityManager
    @Query(filter: #Predicate<PriorityItem> { $0.dateAssigned != nil }, sort: \.orderIndex)
    private var allPriorities: [PriorityItem]
    let date: Date
    let dayNumber: Int
    var onDateSelected: ((Date) -> Void)?
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    private var isFuture: Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
    }
    
    private var prioritiesForDate: [PriorityItem] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return allPriorities.filter { item in
            guard let assignedDate = item.dateAssigned else { return false }
            return assignedDate >= startOfDay && assignedDate < endOfDay
        }.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    private var hasTop1Priority: Bool {
        prioritiesForDate.count > 0
    }
    
    private var top1Completed: Bool {
        let priorities = prioritiesForDate
        return priorities.count > 0 && priorities[0].isCompleted
    }
    
    private var shouldShowGreyBackground: Bool {
        // Show grey for current day when task #1 is not completed
        isToday && hasTop1Priority && !top1Completed
    }
    
    private var shouldShowRedBackground: Bool {
        // Show red if there was a #1 priority but it wasn't completed (past days only)
        !isFuture && hasTop1Priority && !top1Completed && !isToday
    }
    
    private var shouldShowGreenBackground: Bool {
        // Show green when top task is completed
        !isFuture && top1Completed
    }
    
    var body: some View {
        ZStack {
            // Background with gradient heatmap styling
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    shouldShowGreenBackground ?
                        LinearGradient(
                            colors: [Color.anchorStreakGreen.opacity(0.4), Color.anchorStreakTeal.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                    shouldShowRedBackground ?
                        LinearGradient(
                            colors: [Color.anchorStreakRed.opacity(0.4), Color.anchorStreakRed.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                    shouldShowGreyBackground ?
                        LinearGradient(
                            colors: [Color(red: 0.4, green: 0.4, blue: 0.4).opacity(0.4), Color(red: 0.4, green: 0.4, blue: 0.4).opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.clear, Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            shouldShowGreenBackground ?
                                Color.anchorStreakGreen.opacity(0.4) :
                            shouldShowRedBackground ?
                                Color.anchorStreakRed.opacity(0.4) :
                                Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: shouldShowGreenBackground ? Color.anchorStreakGreen.opacity(0.3) :
                           shouldShowRedBackground ? Color.anchorStreakRed.opacity(0.2) : .clear,
                    radius: 4,
                    x: 0,
                    y: 2
                )

            // Watermarked icon with gradient
            if shouldShowGreenBackground {
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if shouldShowRedBackground {
                Image(systemName: "xmark")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 4) {
                // Day number with enhanced styling
                Text("\(dayNumber)")
                    .font(.system(.caption, design: .rounded).weight(isToday ? .bold : .medium))
                    .foregroundStyle(
                        shouldShowGreenBackground || shouldShowRedBackground || shouldShowGreyBackground ? .white :
                        (isFuture ? Color.white.opacity(0.4) : Color.white.opacity(0.9))
                    )
            }
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder((!isFuture && isToday && top1Completed) ? Color.white : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            if !isFuture {
                onDateSelected?(date)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PriorityItem.self, configurations: config)
    let manager = PriorityManager(modelContext: container.mainContext)
    
    return MonthlyView()
        .environment(manager)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

