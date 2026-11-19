import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechCoach: ObservableObject {
    @Published var listening = false
    @Published var heard = ""
    @Published var hint = ""
    @Published var level: Double = 0
    @Published private(set) var onDevice = false

    private var synth = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH"))
    private let audio = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var tapInstalled = false
    private var finishHandler: ((String?) -> Void)?
    private var didFinish = false
    private var triedServer = false
    private var peak: Double = 0
    private var meterSamples = 0
    private var meterTick = Date.distantPast
    private var timeout: Task<Void, Never>?
    private var player: AVAudioPlayer?
    private var generation = 0

    var canListen: Bool { recognizer != nil }

    func refreshAvailability() {
        onDevice = recognizer?.supportsOnDeviceRecognition ?? false
    }

    func requestPermissions() {
        Task { _ = await authorize() }
    }

    func speak(_ text: String, slow: Bool = false, clipID: String? = nil, file: URL? = nil) {
        stopListening()
        synth.stopSpeaking(at: .immediate)
        if let file, ClipLibrary.prefersRecording(hasFile: true, slow: slow), playFile(file) { return }
        if let clipID, ClipLibrary.prefersRecording(hasFile: true, slow: slow),
           let url = Bundle.main.url(forResource: clipID, withExtension: "m4a", subdirectory: "Audio")
            ?? Bundle.main.url(forResource: clipID, withExtension: "m4a"),
           playFile(url) { return }
        synth = AVSpeechSynthesizer()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers])
        try? session.setActive(true)
        let pieces = SpeechPace.chunks(text, slow: slow)
        let rate = SpeechPace.rate(
            slow: slow,
            minimum: AVSpeechUtteranceMinimumSpeechRate,
            defaultRate: AVSpeechUtteranceDefaultSpeechRate
        )
        for (index, piece) in pieces.enumerated() {
            let utterance = AVSpeechUtterance(string: piece)
            utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
            utterance.prefersAssistiveTechnologySettings = false
            utterance.rate = rate
            if slow, index > 0 {
                utterance.preUtteranceDelay = 0.32
            }
            synth.speak(utterance)
        }
    }

    @discardableResult
    private func playFile(_ url: URL) -> Bool {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers])
        try? session.setActive(true)
        guard let next = try? AVAudioPlayer(contentsOf: url) else { return false }
        player = next
        next.play()
        return true
    }

    /// `nil` nur wenn Erkennung oder Mikrofon fehlen. Leerer Text heißt: nichts gehört, das ist kein Treffer.
    func capture(expected: String = "", alternates: [String] = [], onText: @escaping (String?) -> Void) {
        Task { await beginCapture(expected: expected, alternates: alternates, onText: onText) }
    }

    func stop() {
        finish(nil, keepHandler: false)
        synth.stopSpeaking(at: .immediate)
    }

    private func beginCapture(expected: String, alternates: [String], onText: @escaping (String?) -> Void) async {
        synth.stopSpeaking(at: .immediate)
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        if let blocked = await authorize() {
            hint = blocked
            onText(nil)
            return
        }
        guard let recognizer else {
            hint = "Thailändische Spracherkennung ist auf diesem iPhone nicht verfügbar."
            onText(nil)
            return
        }
        guard recognizer.isAvailable else {
            hint = "Spracherkennung ist gerade nicht verfügbar."
            onText(nil)
            return
        }
        stopEngine()
        didFinish = false
        triedServer = false
        peak = 0
        meterSamples = 0
        level = 0
        heard = ""
        finishHandler = onText
        let preferDevice = recognizer.supportsOnDeviceRecognition
        onDevice = preferDevice
        do {
            try startEngine(recognizer: recognizer, expected: expected, alternates: alternates, onDevice: preferDevice)
        } catch {
            hint = "Das Mikrofon lässt sich nicht starten."
            finish(nil)
        }
    }

    private func startEngine(
        recognizer: SFSpeechRecognizer,
        expected: String,
        alternates: [String],
        onDevice: Bool
    ) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
        try session.setActive(true)
        let next = SFSpeechAudioBufferRecognitionRequest()
        next.shouldReportPartialResults = true
        next.requiresOnDeviceRecognition = onDevice
        let context = ([expected] + alternates).filter { !$0.isEmpty }
        if !context.isEmpty {
            next.contextualStrings = context
        }
        self.onDevice = onDevice
        request = next
        let input = audio.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw ListenError.microphone
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            next.append(buffer)
            let value = SpeechCoach.meterLevel(buffer)
            Task { @MainActor in
                self?.noteLevel(value)
            }
        }
        tapInstalled = true
        audio.prepare()
        try audio.start()
        listening = true
        hint = "Ich höre zu…"
        let generation = self.generation
        armTimeout()
        task = recognizer.recognitionTask(with: next) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString ?? ""
            let finished = result?.isFinal ?? false
            Task { @MainActor in
                guard let self, self.generation == generation, !self.didFinish else { return }
                if !text.isEmpty { self.heard = text }
                if error != nil, onDevice, self.heard.isEmpty, !self.triedServer {
                    self.triedServer = true
                    self.hint = "On-Device geht nicht, ich höre über den Server."
                    self.restartOnServer(recognizer: recognizer, expected: expected, alternates: alternates)
                    return
                }
                if finished || error != nil {
                    self.finish(self.heard)
                }
            }
        }
    }

    private func restartOnServer(recognizer: SFSpeechRecognizer, expected: String, alternates: [String]) {
        stopEngine()
        do {
            try startEngine(recognizer: recognizer, expected: expected, alternates: alternates, onDevice: false)
        } catch {
            hint = "Spracherkennung ist gerade nicht verfügbar."
            finish(nil)
        }
    }

    private func noteLevel(_ value: Double) {
        meterSamples += 1
        peak = max(peak, value)
        let now = Date()
        guard now.timeIntervalSince(meterTick) > 0.05 else { return }
        meterTick = now
        level = value
    }

    private func armTimeout() {
        timeout?.cancel()
        timeout = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled, listening else { return }
            finish(heard)
        }
    }

    private func finish(_ text: String?, keepHandler: Bool = true) {
        guard !didFinish else { return }
        didFinish = true
        timeout?.cancel()
        let handler = finishHandler
        finishHandler = nil
        stopEngine()
        guard keepHandler else { return }
        if text == nil {
            if hint.isEmpty { hint = "Spracherkennung ist gerade nicht verfügbar." }
            handler?(nil)
            return
        }
        let said = text ?? ""
        let silence = meterSamples > 3 && peak < 0.01
        if said.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || silence {
            hint = "Nichts gehört."
            heard = ""
            handler?("")
            return
        }
        hint = ""
        handler?(said)
    }

    private func authorize() async -> String? {
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        if speech == .denied || speech == .restricted {
            return "Spracherkennung ist nicht erlaubt. Erlaubt sie in den Einstellungen."
        }
        if speech != .authorized {
            return "Spracherkennung ist nicht erlaubt."
        }
        let mic = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        if !mic {
            return "Mikrofon ist nicht erlaubt. Erlaubt es in den Einstellungen."
        }
        return nil
    }

    private func stopListening() {
        timeout?.cancel()
        didFinish = true
        finishHandler = nil
        stopEngine()
    }

    private func stopEngine() {
        generation += 1
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
        level = 0
    }
}

private enum ListenError: Error {
    case microphone
}

extension SpeechCoach {
    nonisolated static func meterLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        if let data = buffer.floatChannelData {
            let samples = data[0]
            for index in 0..<frames {
                let sample = samples[index]
                sum += sample * sample
            }
        } else if let data = buffer.int16ChannelData {
            let samples = data[0]
            let scale = Float(Int16.max)
            for index in 0..<frames {
                let sample = Float(samples[index]) / scale
                sum += sample * sample
            }
        } else {
            return 0
        }
        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(max(rms, 0.000_01))
        return Double(min(1, max(0, (db + 48) / 42)))
    }
}
