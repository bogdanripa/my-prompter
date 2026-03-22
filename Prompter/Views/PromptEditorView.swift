import SwiftUI

struct PromptEditorView: View {
    @Bindable var prompt: Prompt
    @State private var showTeleprompter = false
    @State private var showTargetPicker = false
    @State private var targetMinutes: Int = 0
    @State private var targetSecs: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title (optional)", text: $prompt.title)
                .font(.title2.bold())
                .padding(.horizontal)
                .padding(.top, 12)
                .onChange(of: prompt.title) {
                    prompt.updatedAt = .now
                }

            Divider()
                .padding(.horizontal)
                .padding(.vertical, 8)

            TextEditor(text: $prompt.body)
                .font(.body)
                .padding(.horizontal, 12)
                .scrollContentBackground(.hidden)
                .onChange(of: prompt.body) {
                    prompt.updatedAt = .now
                }

            Divider()

            HStack {
                Text("\(prompt.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    targetMinutes = prompt.targetSeconds / 60
                    targetSecs = prompt.targetSeconds % 60
                    showTargetPicker = true
                }) {
                    if prompt.hasTarget {
                        Label(formatTime(prompt.targetSeconds), systemImage: "timer")
                            .font(.caption)
                    } else if prompt.wordCount > 0 {
                        Label("~\(estimatedMinutes) min", systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle(prompt.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showTeleprompter = true }) {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(prompt.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .fullScreenCover(isPresented: $showTeleprompter) {
            TeleprompterView(prompt: prompt)
        }
        .sheet(isPresented: $showTargetPicker) {
            targetTimePicker
        }
    }

    private var estimatedMinutes: Int {
        max(1, prompt.wordCount / 150)
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

                if prompt.hasTarget {
                    Button("Remove Target", role: .destructive) {
                        prompt.targetSeconds = 0
                        prompt.updatedAt = .now
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
                        prompt.targetSeconds = targetMinutes * 60 + targetSecs
                        prompt.updatedAt = .now
                        showTargetPicker = false
                    }
                    .disabled(targetMinutes == 0 && targetSecs == 0)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
