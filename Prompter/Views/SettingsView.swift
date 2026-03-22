import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var prompts: [Prompt]
    @AppStorage("fontSize") private var fontSize: Double = 36
    @AppStorage("highlightColor") private var highlightColor: String = "yellow"
    @AppStorage("mirrorMode") private var mirrorMode: Bool = false
    @AppStorage("paceHighlight") private var paceHighlight: Bool = true

    private let colorOptions = ["yellow", "cyan", "green", "orange"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    VStack(alignment: .leading) {
                        Text("Font Size: \(Int(fontSize))pt")
                        Slider(value: $fontSize, in: 20...60, step: 2)
                    }

                    Picker("Highlight Color", selection: $highlightColor) {
                        ForEach(colorOptions, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(Self.color(for: color))
                                    .frame(width: 16, height: 16)
                                Text(color.capitalized)
                            }
                            .tag(color)
                        }
                    }

                    Toggle("Pace-Aware Highlight", isOn: $paceHighlight)

                    if paceHighlight {
                        Text("When a target time is set, the current word turns coral when behind and green when ahead.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Mirror Mode", isOn: $mirrorMode)

                    if mirrorMode {
                        Text("Flips text horizontally for use with a teleprompter mirror/glass setup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Prompts") {
                    Button("Restore Sample Prompts") {
                        SeedData.addSamplePrompts(context: modelContext, existing: prompts)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    static func color(for name: String) -> Color {
        switch name {
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "green": return .green
        case "orange": return .orange
        default: return .yellow
        }
    }
}

#Preview {
    SettingsView()
}
