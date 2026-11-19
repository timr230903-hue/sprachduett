import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechCoach: ObservableObject {
    @Published var listening = false
    @Published var heard = ""
    @Published var hint = ""
    @Published var level: Double = 0
    @Published var bufferCount = 0
    @Published var debugLine = ""
    @Published private(set) var onDevice = false

    private var synth = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: ThaiLanguage().speechLocale))
    private let audio = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var tapInstalled = false
    private var finishHandler: ((String?) -> Void)?
    private var didFinish = false
    private var capture = CaptureSnapshot.idle
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
            utterance.voice = AVSpeechSynthesisVoice(language: ThaiLanguage().speechLocale)
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

    /// Tippen startet, nochmal tippen stoppt. `nil` nur wenn Erkennung oder Mikrofon fehlen.
    func capture(expected: String = "", alternates: [String] = [], onText: @escaping (String?) -> Void) {
        if listening {
            stopCapture()
            return
        }
        Task { await beginCapture(expected: expected, alternates: alternates, onText: onText) }
    }

    func stopCapture() {
        guard listening else { return }
        apply(.userStop)
    }

    func stop() {
        finish(nil, keepHandler: false)
        synth.stopSpeaking(at: .immediate)
    }

    private func beginCapture(expected: String, alternates: [String], onText: @escaping (String?) -> Void) async {
        synth.stopSpeaking(at: .immediate)
        player?.stop()
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
        releaseEngine()
        didFinish = false
        bufferCount = 0
        level = 0
        heard = ""
        capture = CaptureMachine.reduce(.idle, .begin)
        finishHandler = onText
        onDevice = false
        do {
            try startEngine(recognizer: recognizer, expected: expected, alternates: alternates)
        } catch {
            hint = "Das Mikrofon lässt sich nicht starten. \(error.localizedDescription)"
            debugLine = "Session fehlgeschlagen"
            finish(nil)
        }
    }

    /// Session neu aufnehmen, Engine zurücksetzen, Tap erst danach mit dem echten Eingangsformat.
    private func startEngine(
        recognizer: SFSpeechRecognizer,
        expected: String,
        alternates: [String]
    ) throws {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let input = audio.inputNode
        var format = input.outputFormat(forBus: 0)
        if format.sampleRate == 0 || format.channelCount == 0 {
            audio.reset()
            try session.setActive(true)
            format = audio.inputNode.outputFormat(forBus: 0)
        }
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw ListenError.microphone
        }

        let next = SFSpeechAudioBufferRecognitionRequest()
        next.shouldReportPartialResults = true
        next.requiresOnDeviceRecognition = false
        let context = ([expected] + alternates).filter { !$0.isEmpty }
        if !context.isEmpty {
            next.contextualStrings = context
        }
        request = next
        let route = recognizer.supportsOnDeviceRecognition ? "Server (on-device nicht erzwungen)" : "Server"
        debugLine = String(format: "%.0f Hz · %d Kanal · %@", format.sampleRate, format.channelCount, route)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            next.append(buffer)
            let value = SpeechCoach.meterLevel(buffer)
            Task { @MainActor in
                self?.noteBuffer(value)
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
            let message = error?.localizedDescription
            Task { @MainActor in
                guard let self, self.generation == generation, !self.didFinish else { return }
                if !text.isEmpty { self.apply(.partial(text)) }
                if let message, text.isEmpty, !finished {
                    self.hint = "Erkennung: \(message)"
                    self.debugLine = message
                }
                if finished || (error != nil && !text.isEmpty) {
                    self.apply(.userStop)
                }
            }
        }
    }

    private func noteBuffer(_ value: Double) {
        bufferCount += 1
        let now = Date()
        let tick = now.timeIntervalSince(meterTick) > 0.1
        if tick { meterTick = now }
        level = value
        if tick { apply(.level(value)) }
    }

    private func apply(_ event: CaptureEvent) {
        capture = CaptureMachine.reduce(capture, event)
        if !capture.transcript.isEmpty { heard = capture.transcript }
        if let outcome = capture.outcome {
            finish(outcome)
        }
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
        if said.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            hint = bufferCount == 0 ? "Kein Puffer vom Mikrofon." : "Nichts gehört."
            heard = ""
            handler?("")
            return
        }
        hint = ""
        heard = said
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
        releaseEngine()
        listening = false
        level = 0
    }

    private func releaseEngine() {
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
        audio.reset()
    }
}

private enum ListenError: Error {
    case microphone
}

extension SpeechCoach {
    nonisolated static func meterLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        ListenMeter.unitLevel(rms: ListenMeter.rms(samples(from: buffer)))
    }

    nonisolated static func samples(from buffer: AVAudioPCMBuffer) -> [Float] {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return [] }
        let channels = Int(buffer.format.channelCount)
        if let data = buffer.floatChannelData {
            var values: [Float] = []
            values.reserveCapacity(frames * max(channels, 1))
            for channel in 0..<max(channels, 1) {
                let pointer = data[channel]
                for index in 0..<frames {
                    values.append(pointer[index])
                }
            }
            return values
        }
        if let data = buffer.int16ChannelData {
            let scale = Float(Int16.max)
            var values: [Float] = []
            values.reserveCapacity(frames * max(channels, 1))
            for channel in 0..<max(channels, 1) {
                let pointer = data[channel]
                for index in 0..<frames {
                    values.append(Float(pointer[index]) / scale)
                }
            }
            return values
        }
        return []
    }
}
