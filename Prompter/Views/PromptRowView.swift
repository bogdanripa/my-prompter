import SwiftUI

struct PromptRowView: View {
    let prompt: Prompt

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(prompt.displayTitle)
                .font(.headline)
                .lineLimit(1)

            if !prompt.body.isEmpty {
                Text(prompt.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                Text("\(prompt.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if prompt.hasTarget {
                    HStack(spacing: 2) {
                        Image(systemName: "timer")
                        Text(prompt.targetSeconds.timeFormatted)
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
