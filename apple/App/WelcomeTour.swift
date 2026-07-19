import SwiftUI

// First-launch welcome: a warm hello and a 20-second lay of the land.
// The app is self-explanatory, so this is one friendly sheet — not a
// multi-page onboarding gauntlet.

struct WelcomeTour: View {
    let onDone: () -> Void

    static let shownKey = "zoteats.welcomeShown"

    @State private var wave = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.uciGold)
                    .rotationEffect(.degrees(wave ? -8 : 8))
                    .animation(.easeInOut(duration: 0.7).repeatCount(5, autoreverses: true), value: wave)
                    .onAppear { wave = true }
                    .padding(.bottom, 6)

                Text("Welcome, Anteater")
                    .font(ZotFont.hero(30))
                Text("Everything UCI food, one app. Here's the lay of the land:")
                    .font(ZotFont.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 16) {
                tourRow(
                    icon: "fork.knife", tint: Color.uciBlue,
                    title: "Eat",
                    text: "Dining hall menus with filters — heart a dish to get alerts when it's served."
                )
                tourRow(
                    icon: "cup.and.saucer.fill", tint: TagPalette.clay,
                    title: "Campus",
                    text: "Every Starbucks, food court, and market: hours, open-now, and menus."
                )
                tourRow(
                    icon: "dumbbell.fill", tint: TagPalette.sage,
                    title: "Gym",
                    text: "ARC hours and when it's usually packed (or blissfully empty)."
                )
                tourRow(
                    icon: "books.vertical.fill", tint: TagPalette.slate,
                    title: "Study",
                    text: "Live library busyness — find a quiet seat before you walk over."
                )
                tourRow(
                    icon: "gearshape.fill", tint: Color.secondary,
                    title: "Make it yours",
                    text: "The gear up top hides alerts, filters, and a few anteater surprises."
                )
            }

            Spacer(minLength: 20)

            Button(action: onDone) {
                Text("Zot, let's eat")
                    .font(ZotFont.pill.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.uciBlue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("welcome-done")
        }
        .padding(24)
        .background(Color.screen)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    private func tourRow(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZotFont.body.weight(.semibold))
                Text(text)
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        WelcomeTour(onDone: {})
    }
}
