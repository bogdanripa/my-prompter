import SwiftUI

struct TeleprompterView: View {
    let prompt: Prompt
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TeleprompterViewModel()
    @AppStorage("fontSize") private var fontSize: Double = 36
    @AppStorage("mirrorMode") private var mirrorMode: Bool = false
    @AppStorage("highlightColor") private var highlightColorName: String = "yellow"
    @AppStorage("paceHighlight") private var paceHighlight: Bool = true

    private var baseHighlightColor: Color {
        SettingsView.color(for: highlightColorName)
    }

    private var highlightColor: Color {
        guard paceHighlight, viewModel.hasTarget, viewModel.elapsedSeconds > 3 else {
            return baseHighlightColor
        }
        switch paceState {
        case .noTarget, .onPace:
            return baseHighlightColor
        case .behind:
            return Color(red: 1.0, green: 0.45, blue: 0.35)
        case .ahead:
            return Color(red: 0.3, green: 0.9, blue: 0.4)
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progressBar
                textArea
                bottomControls
            }

            if viewModel.isFinished {
                finishedOverlay
                    .transition(.opacity)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            viewModel.start(with: prompt)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.stop()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.elapsedFormatted)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(timerColor)

                if viewModel.hasTarget {
                    paceIndicator
                }
            }
            .animation(.easeInOut(duration: 0.5), value: paceState)

            Spacer()

            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if viewModel.hasTarget {
                    let expectedProgress = min(1, viewModel.elapsedSeconds / Double(viewModel.targetSeconds))
                    Rectangle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 2, height: 4)
                        .offset(x: geo.size.width * expectedProgress)
                        .animation(.easeInOut(duration: 0.5), value: expectedProgress)
                }

                Rectangle()
                    .fill(highlightColor)
                    .frame(width: geo.size.width * viewModel.progress, height: 2)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
            }
        }
        .frame(height: 4)
        .padding(.top, 8)
    }

    // MARK: - Text Area

    private var textArea: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                FlowLayout(spacing: fontSize * 0.25, lineSpacing: fontSize * 0.4) {
                    ForEach(viewModel.words) { word in
                        Text(word.original)
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundStyle(colorForWord(at: word.id))
                            .animation(.easeInOut(duration: 0.3), value: viewModel.currentWordIndex)
                            .flowNewLine(word.startsNewLine)
                            .id("word_\(word.id)")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            .onChange(of: viewModel.currentWordIndex) { _, newIndex in
                withAnimation(.spring(duration: 0.6, bounce: 0)) {
                    scrollProxy.scrollTo("word_\(newIndex)", anchor: .init(x: 0.5, y: 0.3))
                }
            }
            .onChange(of: fontSize) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scrollProxy.scrollTo("word_\(viewModel.currentWordIndex)", anchor: .init(x: 0.5, y: 0.3))
                }
            }
        }
        .scaleEffect(x: mirrorMode ? -1 : 1, y: 1)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 32) {
            Spacer()

            Button(action: { fontSize = max(20, fontSize - 2) }) {
                Image(systemName: "textformat.size.smaller")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 56, height: 56)
            }

            Button(action: {
                if viewModel.isPlaying {
                    viewModel.pause()
                } else {
                    viewModel.start(with: prompt)
                }
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(highlightColor)
            }

            Button(action: { fontSize = min(60, fontSize + 2) }) {
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 56, height: 56)
            }

            Spacer()
        }
        .padding(.bottom, 20)
    }

    // MARK: - Finished Overlay

    private var finishedOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: viewModel.isFinished)

                Text("Well done!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)

                Text(viewModel.elapsedFormatted)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))

                if viewModel.hasTarget {
                    finishedPaceText
                }

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.title3.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(baseHighlightColor, in: Capsule())
                }
                .padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private var finishedPaceText: some View {
        let offset = viewModel.paceOffset
        let absOffset = abs(Int(offset))
        if absOffset < 3 {
            Text("Right on time")
                .font(.title3)
                .foregroundStyle(.green)
        } else if offset > 0 {
            Text("\(absOffset)s ahead of target")
                .font(.title3)
                .foregroundStyle(.cyan)
        } else {
            Text("\(absOffset)s over target")
                .font(.title3)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Pace

    private enum PaceState: Equatable {
        case noTarget, onPace, ahead, behind
    }

    private var paceState: PaceState {
        guard viewModel.hasTarget else { return .noTarget }
        let offset = viewModel.paceOffset
        if abs(offset) < 3 { return .onPace }
        return offset > 0 ? .ahead : .behind
    }

    private var timerColor: Color {
        switch paceState {
        case .noTarget: return .white.opacity(0.8)
        case .onPace: return .green.opacity(0.9)
        case .ahead: return .cyan.opacity(0.9)
        case .behind: return .orange.opacity(0.9)
        }
    }

    @ViewBuilder
    private var paceIndicator: some View {
        let absOffset = abs(Int(viewModel.paceOffset))

        switch paceState {
        case .noTarget:
            EmptyView()
        case .onPace:
            Text("on pace")
                .font(.caption2)
                .foregroundStyle(timerColor)
        case .ahead:
            Text("\(absOffset)s ahead")
                .font(.caption2)
                .foregroundStyle(timerColor)
        case .behind:
            Text("\(absOffset)s behind")
                .font(.caption2)
                .foregroundStyle(timerColor)
        }
    }

    // MARK: - Helpers

    private func colorForWord(at index: Int) -> Color {
        if index < viewModel.currentWordIndex {
            return .white.opacity(0.85)
        } else if index == viewModel.currentWordIndex {
            return highlightColor
        } else {
            return .gray.opacity(0.4)
        }
    }
}
