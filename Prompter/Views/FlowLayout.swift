import SwiftUI

/// Layout value key to signal a forced line break before a view.
struct FlowLayoutNewLine: LayoutValueKey {
    static let defaultValue: Bool = false
}

extension View {
    /// Mark this view as starting a new line in a FlowLayout.
    func flowNewLine(_ value: Bool = true) -> some View {
        layoutValue(key: FlowLayoutNewLine.self, value: value)
    }
}

/// A layout that arranges views in horizontal lines, wrapping to the next line when needed.
/// Supports forced line breaks via the `.flowNewLine()` modifier.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let forceNewLine = subview[FlowLayoutNewLine.self]

            if forceNewLine && currentX > 0 {
                // Forced line break (from original text newlines)
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            } else if currentX + size.width > maxWidth && currentX > 0 {
                // Natural wrap
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return LayoutResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + lineHeight)
        )
    }
}
