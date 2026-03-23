import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(red: 0.078, green: 0.078, blue: 0.137)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)

                Text("My Prompter")
                    .font(.title2.bold())
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
