import SwiftUI

@MainActor
final class LessonLaunch: ObservableObject {
    @Published var playing = false
    @Published var together = true
    @Published var resume = false

    func start(together: Bool, resume: Bool) {
        self.together = together
        self.resume = resume
        playing = true
    }
}

struct ShellView: View {
    @EnvironmentObject private var lessons: LessonLaunch
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            NavigationStack { PathScreen() }
                .tabItem { Label("Lernen", systemImage: "map") }
            NavigationStack { PracticeScreen() }
                .tabItem { Label("Üben", systemImage: "bubble.left.and.bubble.right") }
            NavigationStack { ProgressScreen() }
                .tabItem { Label("Fortschritt", systemImage: "chart.bar") }
            NavigationStack { SettingsSheet(embedded: true, playSolo: {}) }
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                .accessibilityLabel("Einstellungen")
        }
        .tint(Theme.accent)
        .fullScreenCover(isPresented: $lessons.playing) {
            NavigationStack {
                RoundScreen(together: lessons.together, resume: lessons.resume)
            }
        }
        .onChange(of: model.launchSolo) { _, go in
            guard go else { return }
            model.launchSolo = false
            model.clearPausedRound()
            lessons.start(together: false, resume: false)
        }
    }
}

private struct PathScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var screens: ScreenTracker
    @EnvironmentObject private var lessons: LessonLaunch
    @State private var checkLevel: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var nodes: [MapNode] {
        PathMap.nodes(units: model.pathUnits, stats: model.pathStats, checkedStages: model.checkedStages)
    }

    var body: some View {
        ScreenBackground {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Text("🐘").font(.largeTitle).accessibilityHidden(true)
                            Text("Euer Pfad")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        if let daily = model.dailyWord {
                            Text("Wort des Tages · \(daily.thai) · \(daily.german)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 20)
                                .accessibilityLabel("Wort des Tages, \(daily.thai), \(daily.german)")
                        }
                        Text(model.quest.line)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                        ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                            if let chapter = node.chapter {
                                Text(chapter)
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 12)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            lane(index: index) {
                                nodeButton(node)
                            }
                        }
                        if model.pausedRound != nil {
                            Button("Neue Runde") {
                                model.clearPausedRound()
                                lessons.start(together: true, resume: false)
                            }
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            screens.name = "Pfad"
            model.refreshQuestWeek()
            model.refreshNudge()
        }
        .navigationDestination(item: $checkLevel) { level in
            LifeCheckScreen(level: level)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.45), value: nodes.map(\.state))
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Label("\(model.streak.length)", systemImage: "flame.fill")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.accent)
                .accessibilityLabel("Serie \(model.streak.length), ohne Verlust")
            Spacer()
            Label("\(model.stars)", systemImage: "star.fill")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.accent)
                .accessibilityLabel("\(model.stars) Sterne")
            Text(model.partner?.emoji ?? "🌷")
                .font(.title2)
                .padding(6)
                .background(Theme.card, in: Circle())
                .accessibilityLabel("Partner")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func lane<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        let slot = index % 4
        return HStack {
            if slot == 0 || slot == 3 { content(); Spacer(minLength: 0) }
            if slot == 1 { Spacer(minLength: 0); content(); Spacer(minLength: 0) }
            if slot == 2 { Spacer(minLength: 0); content() }
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder private func nodeButton(_ node: MapNode) -> some View {
        let paused = model.pausedRound != nil && node.state == .current && !node.chest
        Button {
            open(node)
        } label: {
            VStack(spacing: 6) {
                if node.state == .current {
                    Text(paused ? "WEITER" : "LOS")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.button, in: Capsule())
                        .foregroundStyle(Color.white)
                }
                ZStack {
                    Circle()
                        .fill(fill(node))
                        .frame(width: 92, height: 92)
                        .overlay(Circle().stroke(Color.black.opacity(0.18), lineWidth: 0).background(Circle().fill(Color.black.opacity(0.18)).offset(y: 5).mask(Circle())))
                    Text(node.state == .locked ? "🔒" : node.emoji).font(.system(size: 36))
                    if node.state == .current {
                        HStack(spacing: -6) {
                            Text(model.me.emoji.isEmpty ? "🐘" : model.me.emoji)
                            Text(model.partner?.emoji ?? "🌷")
                        }
                        .font(.caption)
                        .offset(y: 34)
                    }
                }
                .scaleEffect(node.state == .current ? 1.04 : 1)
                .modifier(Pulse(on: node.state == .current))
                Text(node.title)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .frame(width: 110)
            }
        }
        .buttonStyle(.plain)
        .disabled(node.state == .locked || (node.state == .done && !node.chest))
        .accessibilityIdentifier(identifier(node, paused: paused))
        .accessibilityLabel(node.chest ? node.title : "\(node.title), \(node.state.rawValue)")
    }

    private func identifier(_ node: MapNode, paused: Bool) -> String {
        guard node.state == .current, !node.chest else { return node.id }
        return paused ? "play-resume" : "play-together"
    }

    private func fill(_ node: MapNode) -> Color {
        switch node.state {
        case .done: return Theme.sage
        case .current: return Theme.button
        case .locked: return Theme.card
        }
    }

    private func open(_ node: MapNode) {
        guard node.state != .locked else { return }
        if node.state == .done, !node.chest { return }
        if node.chest {
            checkLevel = node.stage
            return
        }
        let resume = model.pausedRound != nil && node.state == .current
        if !resume { model.clearPausedRound() }
        lessons.start(together: true, resume: resume)
        Haptics.tap()
    }
}

private struct Pulse: ViewModifier {
    let on: Bool
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var big = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(on && big && !reduce ? 1.06 : 1)
            .onAppear { big = true }
            .animation(on && !reduce ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : nil, value: big)
    }
}

struct PracticeScreen: View {
    @State private var route: StudioRoute?

    var body: some View {
        ScreenBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Üben")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Neben dem Pfad, ohne die Runde zu verlassen.")
                        .foregroundStyle(.secondary)
                    FillButton(title: "Ton-Duell", systemImage: "ear") { route = .tone }
                    FillButton(title: "Reise", systemImage: "airplane") { route = .travel }
                        .accessibilityIdentifier("open-travel")
                    FillButton(title: "Eigene Sätze", systemImage: "square.and.pencil") { route = .own }
                    FillButton(title: "Schrift", systemImage: "character.textbox") { route = .script }
                    FillButton(title: "Rollenspiel", systemImage: "theatermasks") { route = .role }
                }
                .padding(20)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(item: $route) { route in
            switch route {
            case .tone: ToneDuelScreen()
            case .script: ScriptScreen()
            case .own: OwnPhraseScreen()
            case .travel: TravelScreen()
            case .role: RolePlayScreen()
            case .share: ShareProgressScreen(sentence: "")
            }
        }
    }
}

struct ProgressScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var share = false
    @State private var feedback = false

    var body: some View {
        ScreenBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Fortschritt")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text(model.headline).font(.title3)
                    Text(model.quest.line).font(.headline)
                    Text(PairQuest.title).font(.footnote).foregroundStyle(.secondary)
                    if model.quest.done {
                        Text("Paar-Quest geschafft").foregroundStyle(Theme.sage).font(.headline)
                    }
                    ForEach(model.persistedChecks) { record in
                        WarmCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.level >= 2 ? "Restaurant-Test" : "Alltags-Check").font(.headline)
                                Text(record.sentence)
                            }
                        }
                    }
                    Text(model.usageLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    FillButton(title: "Karte teilen", systemImage: "square.and.arrow.up") { share = true }
                    FillButton(title: "Feedback", systemImage: "bubble.left") { feedback = true }
                }
                .padding(20)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $share) {
            ShareProgressScreen(sentence: model.headline)
        }
        .sheet(isPresented: $feedback) { FeedbackSheet() }
    }
}
