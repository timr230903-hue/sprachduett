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
    @State private var outcome: LifeCheckOutcome?

    private var steps: [CheckStep] { RealLifeCheck.steps(level: level) }

    var body: some View {
        ScreenBackground {
            VStack(spacing: 16) {
                Text(level >= 2 ? "Restaurant-Test" : "Alltags-Check")
                    .font(.title2.weight(.bold))
                if let outcome {
                    Text(outcome.sentence).font(.title3)
                    FillButton(title: "Fertig") { save(outcome); dismiss() }
                } else if steps.indices.contains(index) {
                    stepView(steps[index])
                }
                Spacer()
            }
            .padding(20)
        }
        .onAppear { screens.name = "Alltags-Check" }
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
        VStack(spacing: 12) {
            Text(prompt.instruction).font(.title3)
            FillButton(title: "Kellner hören") { speech.speak(prompt.waiterThai, slow: true) }
            gradeLabel
            FillButton(title: speech.listening ? "Ich höre zu …" : "Antworten", color: Theme.leaf) {
                speech.capture { text in
                    if let text {
                        grade = SpeechScore.grade(recognized: text, expected: prompt.expected, alternates: prompt.alternates)
                        fallback = false
                    } else {
                        fallback = true
                    }
                }
            }
            if fallback {
                SoftButton(title: "Partner: verstanden") { grade = .sure }
            }
            if grade != nil {
                FillButton(title: "Weiter") { pushSpeak(prompt) }
            }
        }
    }

    private func listenStep(_ question: CheckQuestion) -> some View {
        VStack(spacing: 12) {
            Text("Was bedeutet das?").font(.title3)
            FillButton(title: "Anhören") { speech.speak(question.audio, slow: true) }
            ForEach(question.choices.indices, id: \.self) { choice in
                SoftButton(title: question.choices[choice]) {
                    heard.append((question.canDo, choice == question.answer))
                    advance()
                }
            }
        }
    }

    @ViewBuilder private var gradeLabel: some View {
        if let grade {
            Text(grade == .sure ? "Sicher" : (grade == .close ? "Fast" : "Daneben"))
                .foregroundStyle(grade == .sure ? Theme.leaf : (grade == .close ? Theme.mango : Theme.coral))
        }
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
