import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var screens: ScreenTracker
    @State private var playing = false
    @State private var together = true
    @State private var resume = false
    @State private var showSettings = false
    @State private var showCheck = false
    @State private var feedback = false

    var body: some View {
        ScreenBackground {
            VStack(spacing: 18) {
                HStack {
                    Text("Sprachduett")
                        .font(.headline)
                        .onLongPressGesture { feedback = true }
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityLabel("Einstellungen")
                }
                Button {
                    if model.dueCheckLevel() != nil { showCheck = true }
                } label: {
                    Text(model.headline)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                if let daily = model.dailyWord {
                    Text("Wort des Tages · \(daily.thai) \(daily.german)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                        .accessibilityLabel("Wort des Tages, \(daily.thai), \(daily.german)")
                }
                Text(model.pathSnapshot.label)
                    .font(.title3.weight(.semibold))
                Text(model.pathSnapshot.unitTitle)
                    .foregroundStyle(.secondary)
                ProgressDots(done: model.pathSnapshot.unitIndex, total: model.pathSnapshot.unitCount)
                Spacer()
                if model.pausedRound == nil {
                    playButton("Zusammen spielen") {
                        together = true
                        resume = false
                        playing = true
                    }
                } else {
                    playButton("Weiterspielen") {
                        together = model.pausedRound?.together ?? true
                        resume = true
                        playing = true
                    }
                    Button("Neue Runde") {
                        model.clearPausedRound()
                        together = true
                        resume = false
                        playing = true
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                }
                Text(model.quest.line)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(PairQuest.title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if model.quest.done {
                    Text("Paar-Quest geschafft")
                        .font(.headline)
                        .foregroundStyle(Theme.sage)
                }
                if let party = model.celebration {
                    Text(party)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Button("Schließen") { model.dismissCelebration() }
                        .foregroundStyle(Theme.accent)
                }
                Text("Serie \(model.streak.length)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            screens.name = "Home"
            model.refreshQuestWeek()
            model.refreshNudge()
        }
        .navigationDestination(isPresented: $playing) {
            RoundScreen(together: together, resume: resume)
        }
        .navigationDestination(isPresented: $showCheck) {
            LifeCheckScreen(level: model.dueCheckLevel() ?? 1)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(playSolo: {
                together = false
                resume = false
                showSettings = false
                playing = true
            })
        }
        .sheet(isPresented: $feedback) { FeedbackSheet() }
    }
}

private func playButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.title, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Theme.button, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .foregroundStyle(Color.white)
                .minimumScaleFactor(0.7)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title == "Zusammen spielen" ? "play-together" : "play-resume")
}

private struct ProgressDots: View {
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Circle()
                    .fill(index < done ? Theme.leaf : Theme.mango.opacity(0.35))
                    .frame(width: 12, height: 12)
            }
        }
    }
}

enum StudioRoute: Hashable {
    case tone, script, own, travel, role, share
}

struct SettingsSheet: View {
    var embedded = false
    var playSolo: () -> Void
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var help: HelpRouter
    @EnvironmentObject private var screens: ScreenTracker
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TutorialKey.lesson) private var lessonSeen = false
    @State private var name = ""
    @State private var partnerName = ""
    @State private var leftGender: SpeakerGender = .unspecified
    @State private var rightGender: SpeakerGender = .unspecified
    @State private var showDuo = false
    @State private var feedback = false
    @State private var micTest = false
    @State private var studio: StudioRoute?

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Dein Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                        Text("Links · du").font(.headline)
                        genderPicker(leftGender) { leftGender = $0 }
                        Text(preview(leftGender))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Partner", text: $partnerName)
                            .textFieldStyle(.roundedBorder)
                        Text("Rechts · Partner").font(.headline)
                        genderPicker(rightGender) { rightGender = $0 }
                        Text(preview(rightGender))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Toggle("Umschrift ausblenden", isOn: Binding(
                            get: { model.hideRoman },
                            set: { model.setHideRoman($0) }
                        ))
                        .tint(Theme.accent)
                        FillButton(title: "Sichern") {
                            model.updateSeats(name: name, gender: leftGender, partnerName: partnerName, partnerGender: rightGender)
                        }
                        SoftButton(title: "Solo üben") {
                            if embedded {
                                model.launchSolo = true
                            } else {
                                dismiss()
                                playSolo()
                            }
                        }
                        SoftButton(title: "Duo / Partner") { showDuo = true }
                        SoftButton(title: "Tutorial ansehen") {
                            lessonSeen = false
                            dismiss()
                            help.open()
                        }
                        Text("Serie \(model.streak.length) · Punkte klein, der Alltags-Check zählt.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(ThailandRoute.credit)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Debug")
                            .font(.headline)
                        SoftButton(title: "Mikrofon-Test") { micTest = true }
                        Text(debugText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        SoftButton(title: "Ton-Duell") { studio = .tone }
                        SoftButton(title: "Schrift") { studio = .script }
                        SoftButton(title: "Eigene Sätze") { studio = .own }
                        SoftButton(title: "Reise") { studio = .travel }
                            .accessibilityIdentifier("open-travel")
                        SoftButton(title: "Rollenspiel") { studio = .role }
                        SoftButton(title: "Fortschritt teilen") { studio = .share }
                        SoftButton(title: "Feedback") { feedback = true }
                        if model.hasFeedback {
                            ShareLink(item: model.feedbackExport) { Text("Notizen teilen") }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarBackButtonHidden(false)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } }
                }
            }
            .onAppear {
                screens.name = "Einstellungen"
                name = model.me.name
                partnerName = model.partnerSeatName
                leftGender = model.me.gender
                rightGender = model.persistedPartnerGender
            }
            .sheet(isPresented: $showDuo) { DuoView() }
            .sheet(isPresented: $feedback) { FeedbackSheet() }
            .sheet(isPresented: $micTest) { MicTestScreen() }
            .navigationDestination(item: $studio) { route in
                switch route {
                case .tone: ToneDuelScreen()
                case .script: ScriptScreen()
                case .own: OwnPhraseScreen()
                case .travel: TravelScreen()
                case .role: RolePlayScreen()
                case .share: ShareProgressScreen(sentence: model.headline)
                }
            }
        }
    }

    private func genderPicker(_ value: SpeakerGender, choose: @escaping (SpeakerGender) -> Void) -> some View {
        HStack(spacing: 8) {
            seatButton("ผม ครับ", selected: value == .male) { choose(.male) }
            seatButton("ฉัน ค่ะ", selected: value == .female) { choose(.female) }
        }
    }

    private func seatButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Theme.button : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(selected ? Color.white : Theme.ink)
        }
        .buttonStyle(.plain)
    }

    private func preview(_ gender: SpeakerGender) -> String {
        let form = GenderVoice.speak(thai: "สวัสดี", roman: "sà-wàt-dii", gender: gender, polite: true)
        let mine = GenderVoice.speak(thai: "ผม", roman: "phǒm", gender: gender, polite: false)
        return "\(mine.thai) \(mine.roman) · \(form.thai) \(form.roman)"
    }

    private var debugText: String {
        let usage = model.persistedUsage
        let average = usage.averageSeconds.map { String(Int($0)) + " s" } ?? "–"
        let skips = usage.abandonedByGame.map { "\($0.key) \($0.value)" }.sorted().joined(separator: ", ")
        return "Runden \(usage.roundsStarted), fertig \(usage.roundsFinished), abgebrochen \(usage.abandoned), Dauer \(average). Abbrüche: \(skips.isEmpty ? "keine" : skips)"
    }
}

struct FeedbackSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var screens: ScreenTracker
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bildschirm: \(screens.name)")
                    .foregroundStyle(.secondary)
                TextField("Was fühlt sich komisch an?", text: $note, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(.roundedBorder)
                FillButton(title: "Merken") {
                    model.addFeedback(screen: screens.name, note: note)
                    dismiss()
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }
    }
}
