import SwiftUI
import SwiftData

@main
struct PrompterApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                PromptListView()
                    .preferredColorScheme(.dark)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
            }
        }
        .modelContainer(for: Prompt.self) { result in
            if let container = try? result.get() {
                SeedData.seedIfNeeded(context: container.mainContext)
            }
        }
    }
}

enum SeedData {
    static let sampleTitles = [
        "My First Talk",
        "Welcome to My Prompter",
        "Flying Car Pitch",
        "We Choose the Moon"
    ]

    @MainActor
    static func makeSamples() -> [Prompt] {
        // Reverse display order: list sorts by updatedAt desc, so last inserted appears first.
        // Desired display: 1. Welcome, 2. Moon, 3. Car → insert order: Car, Moon, Welcome
        [
            Prompt(
                title: "Flying Car Pitch",
                body: """
                    Imagine you are stuck in traffic, again. Late for a meeting, wasting hours every week, with no real solution in sight.

                    Now imagine pressing a button and lifting off.

                    This is not science fiction. This is a flying car designed for real, everyday use. It drives like a normal car on the road, fits in a standard parking space, and when needed, transforms into a compact aircraft, taking you above traffic, not through it.

                    You cut a ninety minute commute down to fifteen. City to city trips become seamless. No airports, no waiting, no delays.

                    We are not building a luxury toy. We are building a new layer of transportation. Faster, more efficient, and scalable. With electric propulsion and autonomous assistance, it is safer and cleaner than traditional alternatives.

                    The market is massive. Millions of high income commuters, emergency services, and business travel, all underserved by current infrastructure.

                    We are raising to finalize certification and scale production.

                    This is the moment transportation changes forever.

                    The question is simple. Do you want to invest in the future of mobility, or sit in traffic and watch it fly by?
                    """,
                targetSeconds: 90
            ),
            Prompt(
                title: "We Choose the Moon",
                body: """
                    We choose to go to the moon in this decade and do the other things, not because they are easy, but because they are hard.

                    Because that goal will serve to organize and measure the best of our energies and skills.

                    Because that challenge is one that we are willing to accept, one we are unwilling to postpone, and one which we intend to win.
                    """,
                targetSeconds: 30
            ),
            Prompt(
                title: "Welcome to My Prompter",
                body: """
                    Tap the play button in the top right corner to begin. Now start reading this out loud.

                    See that? The highlighted word is following your voice. Keep going.

                    This is My Prompter, your voice activated teleprompter. It listens to you and scrolls automatically. No buttons, no pedals, no swiping. Just speak and it follows.

                    Try speaking a little faster. See how it keeps up? Now pause for a moment. It waits for you.

                    You can use this for conference talks, pitch rehearsals, wedding speeches, video scripts, or even karaoke night. Anything where you need your text in front of you without losing your place.

                    You can also set a target time for any prompt. If you do, both the timer and the highlighted word change color to guide your pace. Green means slow down, you are ahead. Orange or coral means speed up, you are falling behind.

                    That is it. Paste your text, hit play, and speak. My Prompter takes care of the rest.

                    Your words, your pace, your stage.
                    """,
                targetSeconds: 60
            ),
            Prompt(
                title: "My First Talk",
                body: """
                    - Introduce yourself
                    - Talk about where you live
                    - Ask for support for a great cause
                    - Close with your Instagram for follow ups
                    """
            )
        ]
    }

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        // Only seed once ever, not every time prompts reach zero
        guard !UserDefaults.standard.bool(forKey: "hasSeeded") else { return }

        let descriptor = FetchDescriptor<Prompt>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else {
            // Existing data from before this flag -- mark as seeded
            UserDefaults.standard.set(true, forKey: "hasSeeded")
            return
        }

        for prompt in makeSamples() {
            context.insert(prompt)
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: "hasSeeded")
    }

    /// Add sample prompts that don't already exist (by title). Used from Settings.
    @MainActor
    static func addSamplePrompts(context: ModelContext, existing: [Prompt]) {
        let existingTitles = Set(existing.map(\.title))
        var added = 0

        for prompt in makeSamples() {
            if !existingTitles.contains(prompt.title) {
                context.insert(prompt)
                added += 1
            }
        }

        if added > 0 {
            try? context.save()
        }
    }
}
