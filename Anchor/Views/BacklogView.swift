import SwiftUI
import SwiftData

/// Reports the rendered height of the compact backlog panel so sibling views (e.g. swipe overlays)
/// can avoid drawing underneath it.
struct BacklogVisibleHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // Prefer the latest measurement.
        value = nextValue()
    }
}

struct BacklogView: View {
    @Binding var showFullScreenBacklog: Bool
    @Binding var draftTitle: String
    @Binding var requestFullScreenFocus: Bool
    let selectedDate: Date
    
    @Query(filter: #Predicate<PriorityItem> { $0.dateAssigned == nil }, sort: [SortDescriptor(\.createdAt, order: .reverse)])
    var backlogItems: [PriorityItem]
    
    @Environment(PriorityManager.self) private var priorityManager
    @FocusState private var isInputFocused: Bool
    @State private var panelHeight: CGFloat = Self.minPanelHeight
    @State private var lastPanelHeight: CGFloat = Self.minPanelHeight
    @State private var showLimitAlert = false
    @State private var limitAlertMessage = ""
    @State private var inputAreaMeasuredHeight: CGFloat = 0
    @State private var dragCommittedToExpand: Bool = false
    /// Prevents an iOS focus-restoration blip (e.g. after dismissing the full-screen backlog)
    /// from immediately re-presenting the full-screen cover.
    @State private var suppressFocusDrivenFullScreenPresentation: Bool = false
    
    private static let minPanelHeight: CGFloat = 120
    private static let maxPanelHeight: CGFloat = 520
    private static let inputVisibleThreshold: CGFloat = 200
    private static let snapToMinEpsilon: CGFloat = 22
    private static let snapToInputEpsilon: CGFloat = 28
    private static let expandCommitDragDistance: CGFloat = 18
    
    /// Slightly darker than `anchorCardBg` so the input field's `anchorCardBg` "box"
    /// is visible (matching the full-screen backlog, which sits on `anchorBackground`).
    private var panelBackground: Color {
        Color.anchorCardBg.anchorBlended(with: Color.anchorBackground, fraction: 0.35)
    }
    
    /// Matches the header "bar" tint; also used behind the resize handle so the very top
    /// of the panel doesn't appear darker than the header.
    private var headerBackground: Color {
        Color.anchorCardBg.opacity(0.5)
    }

    private var isMinimized: Bool {
        panelHeight <= (Self.minPanelHeight + 0.5)
    }
    
    private var inputRevealProgress: CGFloat {
        let denom = max(1, Self.inputVisibleThreshold - Self.minPanelHeight)
        let raw = (panelHeight - Self.minPanelHeight) / denom
        return min(1, max(0, raw))
    }
    
    private var inputRevealHeight: CGFloat {
        let fallback: CGFloat = 74 // reasonable default until first measurement
        let full = inputAreaMeasuredHeight > 1 ? inputAreaMeasuredHeight : fallback
        return full * inputRevealProgress
    }

    private func togglePanelHeightFromHandleTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if isMinimized {
                panelHeight = max(panelHeight, Self.inputVisibleThreshold)
            } else {
                panelHeight = Self.minPanelHeight
            }
            lastPanelHeight = panelHeight
        }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                // Drag up => increase height, drag down => decrease height
                if !dragCommittedToExpand, value.translation.height < -Self.expandCommitDragDistance {
                    // Once we know it's an upward swipe (not a tap / slight wobble),
                    // commit to expanding for the rest of this drag to avoid flicker near thresholds.
                    dragCommittedToExpand = true
                }

                let proposed = lastPanelHeight - value.translation.height
                var clamped = min(max(proposed, Self.minPanelHeight), Self.maxPanelHeight)
                if dragCommittedToExpand {
                    clamped = max(clamped, Self.inputVisibleThreshold)
                }
                panelHeight = clamped
            }
            .onEnded { value in
                dragCommittedToExpand = false
                // Fast swipe up => open full-screen backlog
                if value.translation.height < -220 {
                    showFullScreenBacklog = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        panelHeight = Self.minPanelHeight
                        lastPanelHeight = panelHeight
                    }
                    return
                }

                // Swipe down => minimize (header-only)
                if value.translation.height > 80 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        panelHeight = Self.minPanelHeight
                        lastPanelHeight = panelHeight
                    }
                    return
                }

                // Snap behavior:
                // - If the user was expanding (ended on an upward drag) and they didn't reach the input threshold,
                //   resolve to the threshold so the "new task" input is fully visible.
                // - If they end near the minimized height, resolve to minimized.
                let clamped = min(max(panelHeight, Self.minPanelHeight), Self.maxPanelHeight)
                let expanding = value.translation.height < -5
                
                let shouldSnapToMin = clamped <= (Self.minPanelHeight + Self.snapToMinEpsilon)
                let shouldSnapToInput = expanding && clamped < Self.inputVisibleThreshold
                
                let target: CGFloat
                if shouldSnapToMin {
                    target = Self.minPanelHeight
                } else if shouldSnapToInput || abs(clamped - Self.inputVisibleThreshold) <= Self.snapToInputEpsilon {
                    target = Self.inputVisibleThreshold
                } else {
                    target = clamped
                }
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    panelHeight = target
                    lastPanelHeight = target
                }
            }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle for resizing
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 40, height: 5)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(headerBackground)
            .contentShape(Rectangle())
            .onTapGesture(perform: togglePanelHeightFromHandleTap)
            .simultaneousGesture(resizeGesture)
            
            // Header
            HStack {
                Text("Backlog")
                    .anchorFont(.title3, weight: .bold)
                Spacer()
                
                HStack(spacing: 10) {
                    Text("\(backlogItems.count)")
                        .font(.caption)
                        .padding(6)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                    
                    Button {
                        // User intent is to type: take them full-screen so the keyboard doesn't hide the field.
                        requestFullScreenFocus = true
                        showFullScreenBacklog = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        .foregroundStyle(Color.anchorIndigo)
                            .accessibilityLabel("Add to backlog")
                    }
                }
            }
            .padding()
            .background(headerBackground)
            .contentShape(Rectangle())
            .simultaneousGesture(resizeGesture)

            // Input Area (always rendered; smoothly revealed as the panel expands to prevent jitter)
            inputArea
                .frame(height: inputRevealHeight)
                .clipped()
                .opacity(inputRevealProgress)
                .allowsHitTesting(inputRevealProgress > 0.98)
            
            // List (hidden when minimized; minimized state is header-only)
            if !isMinimized {
                if !backlogItems.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(backlogItems) { item in
                                HStack {
                                    Text(item.title)
                                        .anchorFont(.body)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .layoutPriority(1)
                                    Spacer()
                                    
                                    Button {
                                        // "Move to selected date" action
                                        do {
                                            try priorityManager.moveToDate(item, date: selectedDate)
                                        } catch {
                                            limitAlertMessage = error.localizedDescription
                                            showLimitAlert = true
                                        }
                                    } label: {
                                        Image(systemName: "arrow.up.circle")
                                            .foregroundStyle(Color.anchorMint)
                                    }
                                    
                                    Button {
                                        withAnimation {
                                            priorityManager.modelContext.delete(item)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(Color.red)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                        }
                    }
                    .frame(maxHeight: panelHeight)
                } else {
                    // Empty state (only shown when expanded)
                    Text("No backlog items")
                        .anchorFont(.body)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
        .background(panelBackground)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: BacklogVisibleHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onChange(of: isInputFocused) { _, newValue in
            // If the user taps the TextField (or it becomes focused), immediately expand to
            // the full-screen backlog so the keyboard won't obscure what they're typing.
            guard newValue else { return }
            // iOS can restore focus to this TextField after dismissing the full-screen cover,
            // even while the compact panel is minimized. That should *not* reopen the cover.
            guard !suppressFocusDrivenFullScreenPresentation else { return }
            guard !isMinimized else { return }
            requestFullScreenFocus = true
            showFullScreenBacklog = true
            
            // Avoid showing the keyboard in the compact panel while the transition happens.
            DispatchQueue.main.async {
                isInputFocused = false
            }
        }
        .onChange(of: showFullScreenBacklog) { _, newValue in
            // Reset the compact panel to a clean state when we present the full-screen backlog.
            if newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    panelHeight = Self.minPanelHeight
                    lastPanelHeight = Self.minPanelHeight
                }
            } else {
                // We just dismissed the full-screen cover; ignore any transient focus restore.
                suppressFocusDrivenFullScreenPresentation = true
                DispatchQueue.main.async {
                    isInputFocused = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    suppressFocusDrivenFullScreenPresentation = false
                }
            }
        }
        .alert("Cannot Add Task", isPresented: $showLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(limitAlertMessage)
        }
    }

    private var inputArea: some View {
        HStack {
            TextField("Add a new task...", text: $draftTitle)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.anchorCardBg)
                .cornerRadius(8)
                .focused($isInputFocused)
                .submitLabel(.done)
                .onSubmit { addItem() }
            
            Button(action: addItem) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.anchorIndigo)
            }
            .disabled(draftTitle.isEmpty)
        }
        .padding()
        .background(Color.anchorCardBg.opacity(0.5))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: InputAreaHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(InputAreaHeightKey.self) { newValue in
            // Avoid noisy updates while dragging; only accept sane values.
            if newValue > 1, abs(newValue - inputAreaMeasuredHeight) > 0.5 {
                inputAreaMeasuredHeight = newValue
            }
        }
    }
    
    private func addItem() {
        guard !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try priorityManager.addPriority(title: draftTitle, toBacklog: true)
            draftTitle = ""
        } catch {
            limitAlertMessage = error.localizedDescription
            showLimitAlert = true
        }
    }
}

private struct InputAreaHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
