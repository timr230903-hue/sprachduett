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
                Text("Serie \(model.streak.length)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(24)
        }
        .onAppear { screens.name = "Home" }
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
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
    }
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

struct SettingsSheet: View {
    var playSolo: () -> Void
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var help: HelpRouter
    @EnvironmentObject private var screens: ScreenTracker
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TutorialKey.lesson) private var lessonSeen = false
    @State private var name = ""
    @State private var showDuo = false
    @State private var feedback = false

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .onAppear { name = model.me.name }
                        FillButton(title: "Name sichern") {
                            model.updateProfile(name: name, gender: model.me.gender, emoji: model.me.emoji)
                        }
                        SoftButton(title: "Solo üben") { dismiss(); playSolo() }
                        SoftButton(title: "Duo / Partner") { showDuo = true }
                        SoftButton(title: "Tutorial ansehen") {
                            lessonSeen = false
                            dismiss()
                            help.open()
                        }
                        Text("Serie \(model.streak.length) · Punkte klein, der Alltags-Check zählt.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Debug")
                            .font(.headline)
                        Text(debugText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } } }
            .onAppear { screens.name = "Einstellungen" }
            .sheet(isPresented: $showDuo) { DuoView() }
            .sheet(isPresented: $feedback) { FeedbackSheet() }
        }
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
