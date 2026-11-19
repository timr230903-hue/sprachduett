import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechCoach: ObservableObject {
    @Published var listening = false
    @Published var heard = ""
    @Published var hint = ""
    @Published private(set) var onDevice = false

    private let synth = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH"))
    private let audio = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var tapInstalled = false

    var canListen: Bool { recognizer != nil }

    func prepare() {
        onDevice = recognizer?.supportsOnDeviceRecognition ?? false
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    func speak(_ text: String) {
        stopListening()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
        synth.stopSpeaking(at: .immediate)
        synth.speak(utterance)
    }

    func listen(expected: String, onMatch: @escaping () -> Void) {
        stopListening()
        guard let recognizer, recognizer.isAvailable else {
            hint = "Spracherkennung ist gerade nicht da. Dein Partner tippt Verstanden."
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            hint = "Das Mikrofon lässt sich nicht starten."
            return
        }
        let next = SFSpeechAudioBufferRecognitionRequest()
        next.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            next.requiresOnDeviceRecognition = true
            onDevice = true
        } else {
            onDevice = false
        }
        request = next
        let input = audio.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            hint = "Das Mikrofon ist nicht bereit."
            return
        }
        if tapInstalled {
            input.removeTap(onBus: 0)
            tapInstalled = false
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            next.append(buffer)
        }
        tapInstalled = true
        audio.prepare()
        do {
            try audio.start()
        } catch {
            hint = "Das Mikrofon lässt sich nicht starten."
            return
        }
        listening = true
        heard = ""
        hint = onDevice ? "Ich höre auf dem Gerät zu." : "Ich höre zu."
        let gate = ListenGate()
        task = recognizer.recognitionTask(with: next) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString ?? ""
            let matched = SpeechMatch.accepts(recognized: text, expectedThai: expected)
            let finished = result?.isFinal ?? false
            Task { @MainActor in
                guard let self, gate.open else { return }
                if !text.isEmpty { self.heard = text }
                if matched {
                    gate.open = false
                    self.stopListening()
                    onMatch()
                    return
                }
                if finished || error != nil {
                    gate.open = false
                    self.stopListening()
                    if self.heard.isEmpty {
                        self.hint = "Nicht erkannt. Sag es noch einmal, oder dein Partner tippt Verstanden."
                    } else {
                        self.hint = "Das klang noch nicht danach. Nochmal, oder dein Partner tippt Verstanden."
                    }
                }
            }
        }
    }

    func stop() {
        stopListening()
        synth.stopSpeaking(at: .immediate)
    }

    private func stopListening() {
        if audio.isRunning { audio.stop() }
        if tapInstalled {
            audio.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        listening = false
    }
}

private final class ListenGate: @unchecked Sendable {
    var open = true
}
