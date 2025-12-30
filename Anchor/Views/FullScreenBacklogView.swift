import SwiftUI
import SwiftData

struct FullScreenBacklogView: View {
    @Query(filter: #Predicate<PriorityItem> { $0.dateAssigned == nil }, sort: [SortDescriptor(\.createdAt, order: .reverse)])
    var backlogItems: [PriorityItem]
    
    @Environment(PriorityManager.self) private var priorityManager
    @Environment(\.dismiss) private var dismiss
    @Binding var draftTitle: String
    @Binding var requestFocus: Bool
    @Binding var selectedDate: Date
    @FocusState private var isInputFocused: Bool
    @State private var showLimitAlert = false
    @State private var limitAlertMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.anchorBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Input Area
                    HStack {
                        TextField("Add a new task...", text: $draftTitle)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.anchorCardBg)
                            .cornerRadius(8)
                            .focused($isInputFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                addItem()
                            }
                        
                        Button(action: addItem) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.anchorIndigo)
                        }
                        .disabled(draftTitle.isEmpty)
                    }
                    .padding()
                    .background(Color.anchorCardBg.opacity(0.5))
                    
                    // List
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
                                    .background(Color.anchorCardBg)
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    } else {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 64))
                                .foregroundStyle(.secondary)
                            Text("No backlog items")
                                .anchorFont(.title2, weight: .medium)
                                .foregroundStyle(.secondary)
                            Text("Add tasks to your backlog to see them here")
                                .anchorFont(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Backlog")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Ensure the keyboard is dismissed before closing the view.
                        isInputFocused = false
                        // Let the focus change commit before dismissing to avoid "stuck" keyboard.
                        DispatchQueue.main.async {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                // If we were presented because the user tapped the backlog TextField/plus button,
                // immediately focus the full-screen input so they can see what they type.
                if requestFocus {
                    DispatchQueue.main.async {
                        isInputFocused = true
                        requestFocus = false
                    }
                }
            }
            .alert("Cannot Add Task", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(limitAlertMessage)
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

