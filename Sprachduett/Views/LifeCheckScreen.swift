import SwiftUI

struct LifeCheckScreen: View {
    let level: Int
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var speech: SpeechCoach
    @EnvironmentObject private var screens: ScreenTracker
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var grades: [(String, SpeechGrade)] = []
    @State private var heard: [(String, Bool)] = []
    @State private var grade: SpeechGrade?
    @State private var fallback = false
    @State private var picked: Int?
    @State private var outcome: LifeCheckOutcome?

    private var steps: [CheckStep] { RealLifeCheck.steps(level: level) }

    var body: some View {
        ScreenBackground {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    CloseBar { dismiss() }
                        .frame(width: 132)
                    ProgressView(value: progress)
                        .tint(Theme.sage)
                }
                Text(level >= 2 ? "Restaurant-Test" : "Alltags-Check")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let outcome {
                    Text(outcome.sentence).font(.title3)
                    FillButton(title: "Zurück zum Pfad") { save(outcome); dismiss() }
                } else if steps.indices.contains(index) {
                    ScrollView { stepView(steps[index]) }
                    checkDock
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .onAppear { screens.name = "Alltags-Check" }
        .navigationBarBackButtonHidden(true)
        .background(SwipeBackEnabler())
    }

    @ViewBuilder private func stepView(_ step: CheckStep) -> some View {
        switch step {
        case .speak(let prompt):
            speakStep(prompt)
        case .listen(let question):
            listenStep(question)
        }
    }

    private func speakStep(_ prompt: CheckPrompt) -> some View {
        let form = GenderVoice.speak(
            thai: prompt.expected,
            roman: "",
            gender: model.me.gender,
            polite: GenderVoice.usesParticle(prompt.expected, dialog: true)
        )
        return VStack(spacing: 12) {
            Text(prompt.instruction).font(.title3)
            FillButton(title: "Kellner hören") { speech.speak(prompt.waiterThai, slow: true) }
            SpeechListenDeck(
                thai: form.thai,
                roman: form.roman,
                alternates: prompt.alternates + [prompt.expected],
                romanOpacity: model.hideRoman ? 0 : 1,
                speech: speech,
                grade: $grade,
                fallback: $fallback
            )
        }
    }

    private func listenStep(_ question: CheckQuestion) -> some View {
        VStack(spacing: 12) {
            Text("Was bedeutet das?").font(.title3)
            FillButton(title: "Anhören") { speech.speak(question.audio, slow: true) }
            ForEach(question.choices.indices, id: \.self) { choice in
                Button {
                    picked = choice
                    Haptics.tap()
                } label: {
                    Text(question.choices[choice])
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(picked == choice ? Theme.button : Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(picked == choice ? Color.white : Theme.ink)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var checkDock: some View {
        if steps.indices.contains(index), case .speak(let prompt) = steps[index], let grade {
            FeedbackBanner(grade: grade) { pushSpeak(prompt) }
        } else if steps.indices.contains(index), case .listen(let question) = steps[index] {
            FillButton(title: "CHECK", enabled: picked != nil) {
                guard let picked else { return }
                let right = picked == question.answer
                if right { Haptics.success() } else { Haptics.warning() }
                heard.append((question.canDo, right))
                self.picked = nil
                advance()
            }
        } else {
            FillButton(title: "CHECK", enabled: false) {}
        }
    }

    private var progress: Double {
        if outcome != nil { return 1 }
        return Double(index) / Double(max(steps.count, 1))
    }

    private func pushSpeak(_ prompt: CheckPrompt) {
        grades.append((prompt.canDo, grade ?? .miss))
        grade = nil
        fallback = false
        advance()
    }

    private func advance() {
        if index + 1 >= steps.count {
            outcome = RealLifeCheck.outcome(grades: grades, comprehension: heard)
        } else {
            index += 1
        }
    }

    private func save(_ outcome: LifeCheckOutcome) {
        model.saveCheck(CheckRecord(
            id: UUID().uuidString,
            date: Date(),
            level: level,
            sentence: outcome.sentence,
            achieved: outcome.achieved
        ))
    }
}
