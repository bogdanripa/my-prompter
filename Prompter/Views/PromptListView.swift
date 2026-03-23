import SwiftUI
import SwiftData

struct PromptListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Prompt.updatedAt, order: .reverse) private var prompts: [Prompt]
    @State private var selectedPrompt: Prompt?
    @State private var showSettings = false
    @State private var targetPrompt: Prompt?
    @State private var showTargetPicker = false
    @State private var targetMinutes: Int = 0
    @State private var targetSecs: Int = 0

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPrompt) {
                ForEach(prompts) { prompt in
                    NavigationLink(value: prompt) {
                        PromptRowView(prompt: prompt)
                    }
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            if selectedPrompt == prompt { selectedPrompt = nil }
                            modelContext.delete(prompt)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            targetPrompt = prompt
                            targetMinutes = prompt.targetSeconds / 60
                            targetSecs = prompt.targetSeconds % 60
                            showTargetPicker = true
                        } label: {
                            Label("Target", systemImage: "timer")
                        }
                        .tint(.orange)
                    }
                }
            }
            .navigationTitle("My Prompter")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addPrompt) {
                        Label("New Prompt", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .overlay {
                if prompts.isEmpty {
                    ContentUnavailableView(
                        "No Prompts",
                        systemImage: "text.alignleft",
                        description: Text("Tap + to create your first prompt")
                    )
                }
            }
            .onAppear { cleanupEmptyPrompts() }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showTargetPicker) {
                targetTimePicker
            }
        } detail: {
            if let prompt = selectedPrompt {
                PromptEditorView(prompt: prompt)
            } else {
                ContentUnavailableView(
                    "Select a Prompt",
                    systemImage: "text.alignleft",
                    description: Text("Choose a prompt from the sidebar or create a new one")
                )
            }
        }
    }

    private func addPrompt() {
        let prompt = Prompt()
        modelContext.insert(prompt)
        selectedPrompt = prompt
    }

    private func cleanupEmptyPrompts() {
        for prompt in prompts {
            if prompt.title.isEmpty && prompt.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if selectedPrompt == prompt { selectedPrompt = nil }
                modelContext.delete(prompt)
            }
        }
    }

    private var targetTimePicker: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Target Time")
                    .font(.headline)

                HStack(spacing: 0) {
                    Picker("Minutes", selection: $targetMinutes) {
                        ForEach(0..<60, id: \.self) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)

                    Text("min")
                        .foregroundStyle(.secondary)

                    Picker("Seconds", selection: $targetSecs) {
                        ForEach(0..<60, id: \.self) { s in
                            Text(String(format: "%02d", s)).tag(s)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)

                    Text("sec")
                        .foregroundStyle(.secondary)
                }

                if let p = targetPrompt, p.hasTarget {
                    Button("Remove Target", role: .destructive) {
                        p.targetSeconds = 0
                        p.updatedAt = Date()
                        showTargetPicker = false
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTargetPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        if let p = targetPrompt {
                            p.targetSeconds = targetMinutes * 60 + targetSecs
                            p.updatedAt = Date()
                        }
                        showTargetPicker = false
                    }
                    .disabled(targetMinutes == 0 && targetSecs == 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    PromptListView()
        .modelContainer(for: Prompt.self, inMemory: true)
}
