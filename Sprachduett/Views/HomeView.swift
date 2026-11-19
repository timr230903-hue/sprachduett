import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    var openDuets: () -> Void

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Heute")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        peopleCard
                        streakCard
                        FillButton(title: "Ein Duett sprechen", systemImage: "bubble.left.and.bubble.right") {
                            openDuets()
                        }
                    }
                    .padding(20)
                }
            }
            .overlay {
                if let text = model.celebration {
                    CelebrationCover(text: text) { model.dismissCelebration() }
                }
            }
            .onChange(of: model.celebration) { _, text in
                if text != nil { Haptics.success() }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { HelpButton() } }
        }
    }

    private var peopleCard: some View {
        WarmCard {
            HStack(spacing: 16) {
                PersonBubble(emoji: model.me.emoji, name: model.me.name, points: model.points(for: model.me.id), done: model.streak.practicedToday.contains(model.me.id))
                Image(systemName: "heart.fill").foregroundStyle(Theme.mango)
                if let partner = model.partner {
                    PersonBubble(emoji: partner.emoji, name: partner.name, points: model.points(for: partner.id), done: model.streak.practicedToday.contains(partner.id))
                } else {
                    PersonBubble(emoji: "➕", name: "Partner", points: 0, done: false)
                }
            }
        }
    }

    private var streakCard: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Serie")
                    .font(.headline)
                Text("\(model.streak.length)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text(streakLine)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var streakLine: String {
        if model.memberIDs.count >= 2 && !model.streak.todayBoth {
            return "Die Serie zählt erst, wenn ihr heute beide eine Zeile laut gesagt habt."
        }
        if model.streak.todayBoth {
            return "Heute seid ihr dran. Weiter so."
        }
        return "Eine Zeile laut gesagt reicht, um den Tag zu zählen."
    }
}

struct PersonBubble: View {
    let emoji: String
    let name: String
    let points: Int
    let done: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(emoji).font(.system(size: 40))
            Text(name.isEmpty ? "Ich" : name).font(.headline)
            Text("\(points) Punkte").font(.caption).foregroundStyle(.secondary)
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Theme.leaf : Color.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CelebrationCover: View {
    let text: String
    let close: () -> Void
    @State private var on = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("🔥")
                    .font(.system(size: 64))
                    .scaleEffect(on ? 1 : 0.3)
                Text(text)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                FillButton(title: "Weiter", action: close)
            }
            .padding(24)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(32)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.45)) { on = true }
        }
    }
}
