import SwiftUI

struct SpeechListenDeck: View {
    let thai: String
    let roman: String
    let alternates: [String]
    let romanOpacity: Double
    let speech: SpeechCoach
    @Binding var grade: SpeechGrade?
    @Binding var fallback: Bool
    @State private var litSure = 0

    private var tokens: [LiveToken] {
        SpeechScore.liveTokens(
            recognized: speech.heard,
            expected: thai,
            roman: roman,
            finished: grade != nil || (!speech.listening && !speech.heard.isEmpty && grade == nil && fallback)
        )
    }

    private var shownOpacity: Double {
        if speech.listening || grade == .close || grade == .miss { return 1 }
        return romanOpacity
    }

    var body: some View {
        VStack(spacing: 12) {
            thaiLine
            syllableRow
                .opacity(shownOpacity)
            if speech.listening {
                Text("Ich höre zu…")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
            }
            if !speech.heard.isEmpty {
                Text(speech.heard)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
            }
            Waveform(level: speech.level, listening: speech.listening)
            MicButton(
                listening: speech.listening,
                toggle: { startOrStop() },
                holdBegan: { if !speech.listening { startOrStop() } },
                holdEnded: { speech.stopCapture() }
            )
            if let grade {
                let note = SpeechHint.explain(recognized: speech.heard, expected: thai, roman: roman)
                Text(resultTitle(grade))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(resultColor(grade))
                Text(note.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let tone = note.tone, grade != .sure {
                    Text("\(note.syllable ?? "") \(tone.arrow)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(toneColor(tone))
                        .accessibilityLabel("Ton \(tone.arrow)")
                }
                if grade != .sure {
                    FillButton(title: "Langsam hören", systemImage: "tortoise") {
                        speech.speak(thai, slow: true)
                    }
                }
            }
            if !speech.hint.isEmpty, grade == nil || speech.hint == "Nichts gehört." {
                Text(speech.hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if fallback {
                SoftButton(title: "Partner: Richtig") { grade = .sure; fallback = false }
                SoftButton(title: "Partner: Nochmal") { grade = .miss; fallback = false }
            }
        }
        .onChange(of: sureCount) { _, count in
            if count > litSure {
                Haptics.success()
                litSure = count
            }
        }
    }

    private func startOrStop() {
        if speech.listening {
            speech.stopCapture()
            return
        }
        grade = nil
        fallback = false
        litSure = 0
        speech.capture(expected: thai, alternates: alternates) { text in
            if let text {
                fallback = false
                grade = SpeechScore.grade(recognized: text, expected: thai, alternates: alternates)
            } else {
                fallback = true
                grade = nil
            }
        }
    }

    private var sureCount: Int {
        tokens.filter { $0.light == .sure }.count
    }

    private var thaiLine: some View {
        Text(thai)
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.center)
            .foregroundStyle(thaiColor)
            .opacity(thaiVisible ? 1 : 0)
    }

    var hidesThaiUntilListening: Bool = false

    private var thaiVisible: Bool {
        if !hidesThaiUntilListening { return true }
        return speech.listening || grade != nil || !speech.heard.isEmpty
    }

    private var thaiColor: Color {
        if tokens.contains(where: { $0.light == .miss }) { return Theme.brick }
        if !tokens.isEmpty, tokens.allSatisfy({ $0.light == .sure }) { return Theme.leaf }
        if tokens.contains(where: { $0.light == .close }) { return Theme.accent }
        return Theme.ink
    }

    private var syllableRow: some View {
        HStack(spacing: 8) {
            ForEach(tokens) { token in
                Text(token.text)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tokenColor(token))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(tokenColor(token).opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func tokenColor(_ token: LiveToken) -> Color {
        switch token.light {
        case .pending:
            return RomanTones.tone(of: token.text) == .mid ? Theme.ink : toneColor(RomanTones.tone(of: token.text))
        case .sure: return Theme.leaf
        case .close: return Theme.accent
        case .miss: return Theme.brick
        }
    }

    private func toneColor(_ tone: ToneColor) -> Color {
        switch tone {
        case .mid: return Theme.ink
        case .low: return Color(red: 0.20, green: 0.45, blue: 0.75)
        case .falling: return Theme.brick
        case .high: return Theme.accent
        case .rising: return Theme.leaf
        }
    }

    private func resultTitle(_ grade: SpeechGrade) -> String {
        switch grade {
        case .sure: return "Sicher"
        case .close: return "Fast"
        case .miss: return "Daneben"
        }
    }

    private func resultDetail(_ grade: SpeechGrade) -> String {
        switch grade {
        case .sure: return "Das war die Zeile."
        case .close: return "Knapp daneben. Hört nochmal langsam hin."
        case .miss: return speech.heard.isEmpty ? "Nichts gehört." : "Das war eine andere Zeile."
        }
    }

    private func resultColor(_ grade: SpeechGrade) -> Color {
        switch grade {
        case .sure: return Theme.leaf
        case .close: return Theme.accent
        case .miss: return Theme.brick
        }
    }
}

struct MicButton: View {
    let listening: Bool
    let toggle: () -> Void
    var holdBegan: () -> Void = {}
    var holdEnded: () -> Void = {}
    @State private var holding = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !listening)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let wave = listening ? 0.5 + 0.5 * sin(time * 5) : 0
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.22))
                    .frame(width: 104, height: 104)
                    .scaleEffect(1 + wave * 0.16)
                Circle()
                    .fill(Theme.button)
                    .frame(width: 74, height: 74)
                Image(systemName: listening ? "stop.fill" : "mic.fill")
                    .font(.title)
                    .foregroundStyle(Color.white)
            }
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !holding else { return }
                    holding = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        guard holding, !listening else { return }
                        holdBegan()
                    }
                }
                .onEnded { _ in
                    let wasHold = listening
                    let pressed = holding
                    holding = false
                    if pressed, wasHold {
                        holdEnded()
                    } else if pressed {
                        toggle()
                    }
                }
        )
        .accessibilityLabel(listening ? "Aufnahme stoppen" : "Sprechen")
        .accessibilityHint("Tippen startet und stoppt. Gedrückt halten spricht nur so lange.")
    }
}

struct MicTestScreen: View {
    @EnvironmentObject private var speech: SpeechCoach
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenBackground {
            VStack(spacing: 14) {
                CloseBar { speech.stopCapture(); dismiss() }
                Text("Mikrofon-Test")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text(String(format: "Pegel %.2f · Puffer %d", speech.level, speech.bufferCount))
                    .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                Waveform(level: speech.level, listening: speech.listening)
                Text(speech.heard.isEmpty ? "Noch kein Text" : speech.heard)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                Text(speech.debugLine.isEmpty ? speech.hint : speech.debugLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                MicButton(
                    listening: speech.listening,
                    toggle: { startOrStop() },
                    holdBegan: { if !speech.listening { startOrStop() } },
                    holdEnded: { speech.stopCapture() }
                )
                Spacer()
            }
            .padding(20)
        }
        .navigationBarBackButtonHidden(true)
    }

    private func startOrStop() {
        if speech.listening {
            speech.stopCapture()
            return
        }
        speech.capture(expected: "สวัสดี", alternates: ["สบายดี"]) { _ in }
    }
}

struct Waveform: View {
    let level: Double
    let listening: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !listening)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(listening ? Theme.accent : Theme.navy.opacity(0.25))
                        .frame(width: 6, height: height(index: index, time: time))
                }
            }
            .frame(height: 52)
        }
        .accessibilityLabel("Pegel")
    }

    private func height(index: Int, time: TimeInterval) -> CGFloat {
        let idle: CGFloat = 8
        guard listening else { return idle }
        let shape = 0.45 + 0.55 * abs(sin(time * 7 + Double(index) * 0.55))
        return idle + CGFloat(level) * 40 * shape
    }
}
