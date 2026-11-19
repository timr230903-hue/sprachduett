import SwiftUI

struct SessionView: View {
    let sceneID: String
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var coach: SpeechCoach
    @AppStorage(TutorialKey.lesson) private var lessonSeen = false
    @State private var tourStep = 0

    var body: some View {
        ScreenBackground {
            if let scene = model.catalog.scene(sceneID) {
                SessionBody(scene: scene)
            } else {
                Text("Diese Szene fehlt.")
            }
        }
        .navigationTitle(model.catalog.scene(sceneID)?.title ?? "Duett")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if !lessonSeen, model.catalog.scene(sceneID) != nil {
                LessonCoach(step: tourStep) { advanceTour() }
            }
        }
        .onDisappear { coach.stop() }
    }

    private func advanceTour() {
        if let next = LessonTour.advance(step: tourStep) {
            tourStep = next
        } else {
            lessonSeen = true
        }
    }
}

private struct SessionBody: View {
    let scene: DuettScene
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let turn = model.turn(for: scene)
        VStack(spacing: 16) {
            if case .done = turn.phase {
                DonePane(scene: scene)
            } else if case .handoff(let role) = turn.phase {
                HandoffPane(scene: scene, role: role)
            } else if turn.phase == .listen {
                ListenPane(scene: scene)
            } else if let line = turn.line {
                SpeakPane(scene: scene, line: line)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}

private struct SpeakPane: View {
    let scene: DuettScene
    let line: DuettLine
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var coach: SpeechCoach

    var body: some View {
        let spoken = model.spoken(line)
        VStack(alignment: .leading, spacing: 14) {
            Text("Deine Zeile")
                .font(.headline)
                .foregroundStyle(Theme.coral)
            Text(spoken.thai)
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text(spoken.roman)
                .font(.title3)
            Text(line.german)
                .foregroundStyle(.secondary)
            if model.needsRepeat {
                Text("Noch einmal. Dein Partner hat es nicht verstanden.")
                    .foregroundStyle(Theme.coral)
            }
            if !coach.hint.isEmpty {
                Text(coach.hint).font(.footnote).foregroundStyle(.secondary)
            }
            if !coach.heard.isEmpty {
                Text("Gehört: \(coach.heard)").font(.footnote)
            }
            FillButton(title: coach.listening ? "Ich höre zu …" : "Anhören", systemImage: "speaker.wave.2") {
                coach.speak(spoken.thai)
            }
            FillButton(title: "Laut zum Partner sagen", systemImage: "mic", color: Theme.leaf) {
                coach.listen(expected: spoken.thai) { model.confirmCurrent(in: scene) }
            }
            if passPhone || !coach.canListen {
                SoftButton(title: "Gesagt") { model.confirmCurrent(in: scene) }
            }
        }
    }

    private var passPhone: Bool { model.duo.session?.passPhone ?? false }
}

private struct ListenPane: View {
    let scene: DuettScene
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("👂").font(.system(size: 64))
            Text("Jetzt spricht \(speakerName).")
                .font(.title2.weight(.bold))
            Text("Schau sie oder ihn an. Die thailändische Zeile steht nur auf dem anderen Handy.")
                .foregroundStyle(.secondary)
            if model.needsRepeat {
                Text("Du hast um eine Wiederholung gebeten.")
                    .foregroundStyle(Theme.coral)
            }
            FillButton(title: "Verstanden", systemImage: "checkmark") {
                model.confirmCurrent(in: scene)
            }
            SoftButton(title: "Bitte noch einmal") { model.requestRepeat() }
        }
    }

    private var speakerName: String {
        guard let session = model.duo.session, let line = TurnEngine.currentLine(scene: scene, snapshot: session) else {
            return "dein Partner"
        }
        return model.duo.member(for: line.role)?.name ?? scene.roleTitle(line.role)
    }
}

private struct HandoffPane: View {
    let scene: DuettScene
    let role: DuettRole
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📱").font(.system(size: 64))
            Text("Handy an \(scene.roleTitle(role))")
                .font(.title2.weight(.bold))
            Text("Nicht mitlesen. Erst weitergeben, dann die eigene Zeile aufdecken.")
                .foregroundStyle(.secondary)
            FillButton(title: "Ich bin \(scene.roleTitle(role))") {
                model.acceptHandoff(in: scene)
            }
            SoftButton(title: "Letzte Zeile noch einmal") { model.rewind(in: scene) }
        }
    }
}

private struct DonePane: View {
    let scene: DuettScene

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎉").font(.system(size: 64))
            Text("Szene geschafft")
                .font(.title.weight(.bold))
            Text("\(scene.title) habt ihr einander vorgesprochen.")
                .foregroundStyle(.secondary)
        }
    }
}
