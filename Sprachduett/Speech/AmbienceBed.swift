import AVFoundation

/// Kurzes, selbst erzeugtes Rauschen. Keine fremden Aufnahmen.
final class AmbienceBed {
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var kind: AmbienceKind = .market
    private var phase: Double = 0

    func start(_ kind: AmbienceKind) {
        stop()
        self.kind = kind
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
        try? session.setActive(true)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else { return }
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = self?.nextSample() ?? 0
                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    data[frame] = sample
                }
            }
            return noErr
        }
        source = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.2
        try? engine.start()
    }

    func stop() {
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
    }

    private func nextSample() -> Float {
        phase += 1
        let noise = Float.random(in: -1...1)
        switch kind {
        case .market:
            return noise * 0.22
        case .massage:
            let swell = Float(0.55 + 0.45 * sin(phase / 7000))
            return noise * 0.07 * swell
        case .tuktuk:
            let hit = sin(phase / 1600) > 0.2
            return noise * (hit ? 0.32 : 0.04)
        }
    }
}
