import AudioToolbox
import AVFoundation
import SwiftUI

struct ToneDuelScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var speech: SpeechCoach
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var leftTurn = true
    @State private var note = ""

    private var rounds: [ToneRound] {
        ToneDuel.rounds(knownIDs: Set(model.catalog.phrases.map(\.id)))
    }

    var body: some View {
        ScreenBackground {
            VStack(spacing: 16) {
                CloseBar { dismiss() }
                if rounds.isEmpty {
                    Text("Keine Tonpaare im Katalog.")
                } else {
                    let round = rounds[index % rounds.count]
                    let speaker = leftTurn ? model.me.name.ifEmpty("Du") : model.partnerSeatName
                    Text("\(speaker): welcher Ton war das?")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(leftTurn ? Theme.navy : Theme.accent)
                        .accessibilityAddTraits(.isHeader)
                    if let prompt = phrase(round.promptID) {
                        FillButton(title: "Anhören", systemImage: "speaker.wave.2") {
                            speech.speak(prompt.thai, clipID: prompt.id)
                        }
                        ForEach(round.optionIDs, id: \.self) { id in
                            if let option = phrase(id) {
                                SoftButton(title: "\(option.thai)  \(option.roman)") {
                                    let hit = ToneDuel.hit(promptID: round.promptID, choiceID: id)
                                    note = hit ? "Stimmt." : "Anderer Ton."
                                    if hit { Haptics.success() } else { Haptics.warning() }
                                    leftTurn.toggle()
                                    index += 1
                                }
                                .accessibilityLabel(option.german)
                            }
                        }
                    }
                    Text(note).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
        }
        .navigationBarBackButtonHidden(true)
    }

    private func phrase(_ id: String) -> Phrase? {
        model.catalog.phrases.first { $0.id == id }
    }
}

struct ScriptScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenBackground {
            VStack(alignment: .leading, spacing: 16) {
                CloseBar { dismiss() }
                Text("Ein paar Buchstaben, dann ein Schild.")
                    .font(.title3)
                let open = model.scriptUnlocked
                if open == 0 {
                    Text("Morgen gibt es die nächsten Buchstaben.")
                }
                ForEach(ScriptCourse.lessons.prefix(open)) { lesson in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lesson.title).font(.headline)
                        HStack(spacing: 12) {
                            ForEach(lesson.glyphs) { glyph in
                                VStack {
                                    Text(glyph.glyph).font(.largeTitle)
                                    Text(glyph.roman).font(.caption)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(glyph.glyph), \(glyph.name)")
                            }
                        }
                        SignMock(thai: lesson.sign, german: lesson.signGerman)
                    }
                }
                if model.canFinishScript {
                    FillButton(title: "Heute geschafft") { model.completeScriptLesson() }
                }
                Spacer()
            }
            .padding(20)
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct SignMock: View {
    let thai: String
    let german: String

    var body: some View {
        VStack(spacing: 4) {
            Text(thai)
                .font(.system(size: 48, weight: .black, design: .rounded))
                .minimumScaleFactor(0.5)
                .foregroundStyle(Color.black)
            Text(german)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schild \(thai), \(german)")
    }
}

struct OwnPhraseScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var speech: SpeechCoach
    @Environment(\.dismiss) private var dismiss
    @State private var german = ""
    @State private var thai = ""
    @State private var roman = ""
    @State private var recording = false
    @State private var recorder: AVAudioRecorder?
    @State private var audioName: String?

    var body: some View {
        ScreenBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    CloseBar { dismiss() }
                    Text("Deutsch tippen, im Heft suchen oder Thai selbst eintragen.")
                        .font(.body)
                    TextField("Deutsch", text: $german)
                        .textFieldStyle(.roundedBorder)
                    ForEach(hits) { hit in
                        SoftButton(title: "\(hit.german) · \(hit.thai)") {
                            german = hit.german
                            thai = hit.thai
                            roman = hit.roman
                        }
                    }
                    TextField("Thai", text: $thai)
                        .textFieldStyle(.roundedBorder)
                    TextField("Umschrift", text: $roman)
                        .textFieldStyle(.roundedBorder)
                    FillButton(title: recording ? "Aufnahme stoppen" : "Partner nimmt auf", systemImage: "mic") {
                        toggleRecording()
                    }
                    FillButton(title: "Karte für beide sichern") { save() }
                        .disabled(thai.trimmingCharacters(in: .whitespaces).isEmpty || german.trimmingCharacters(in: .whitespaces).isEmpty)
                    ForEach(model.ownCards) { card in
                        SoftButton(title: "\(card.german) · \(card.thai)") {
                            speech.speak(card.thai, file: model.audioURL(named: card.audioName))
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var hits: [PhraseHit] {
        Phrasebook.search(german, phrases: model.phraseHits)
    }

    private func toggleRecording() {
        if recording {
            recorder?.stop()
            recording = false
            return
        }
        let name = UUID().uuidString
        let url = model.audioFolder().appendingPathComponent("\(name).m4a")
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
        ]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        audioName = name
        recording = recorder?.isRecording ?? false
    }

    private func save() {
        recorder?.stop()
        recording = false
        model.addOwn(OwnCard(
            id: UUID().uuidString,
            german: german.trimmingCharacters(in: .whitespacesAndNewlines),
            thai: thai.trimmingCharacters(in: .whitespacesAndNewlines),
            roman: roman.trimmingCharacters(in: .whitespacesAndNewlines),
            audioName: audioName
        ))
        german = ""
        thai = ""
        roman = ""
        audioName = nil
        Haptics.success()
    }
}

struct TravelScreen: View {
    @EnvironmentObject private var speech: SpeechCoach
    @Environment(\.dismiss) private var dismiss
    @State private var placeID = TravelDeck.places[0].id

    var body: some View {
        ScreenBackground {
            VStack(spacing: 16) {
                CloseBar { dismiss() }
                Picker("Ort", selection: $placeID) {
                    ForEach(TravelDeck.places) { place in
                        Text(place.title).tag(place.id)
                    }
                }
                .pickerStyle(.segmented)
                if let place = TravelDeck.places.first(where: { $0.id == placeID }) {
                    ForEach(place.lines) { line in
                        VStack(spacing: 6) {
                            Text(line.thai)
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .minimumScaleFactor(0.4)
                                .multilineTextAlignment(.center)
                            Text(line.roman).font(.title3).foregroundStyle(Theme.accent)
                            Text(line.german).font(.body)
                            FillButton(title: "Vorlesen", systemImage: "speaker.wave.2") {
                                speech.speak(line.thai, clipID: line.id)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Spacer()
            }
            .padding(16)
        }
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("travel-screen")
    }
}

struct RolePlayScreen: View {
    @EnvironmentObject private var speech: SpeechCoach
    @Environment(\.dismiss) private var dismiss
    @State private var bed = AmbienceBed()
    @State private var sceneID = RolePlay.scenes[0].id

    var body: some View {
        ScreenBackground {
            VStack(spacing: 16) {
                CloseBar {
                    bed.stop()
                    dismiss()
                }
                ForEach(RolePlay.scenes) { scene in
                    SoftButton(title: scene.title) {
                        sceneID = scene.id
                        bed.start(scene.ambience)
                        Haptics.tap()
                    }
                }
                if let scene = RolePlay.scenes.first(where: { $0.id == sceneID }) {
                    Text(scene.ambience.title).font(.headline).foregroundStyle(Theme.accent)
                    Text(scene.line.thai).font(.largeTitle.weight(.bold)).minimumScaleFactor(0.5)
                    Text(scene.line.german)
                    FillButton(title: "Satz hören") { speech.speak(scene.line.thai, clipID: scene.line.id) }
                    Text("Die Geräusche sind hier erzeugt, nicht aufgenommen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear { bed.stop() }
    }
}

struct ShareProgressScreen: View {
    let sentence: String
    @Environment(\.dismiss) private var dismiss
    @State private var picture: Image?

    var body: some View {
        ScreenBackground {
            VStack(spacing: 16) {
                CloseBar { dismiss() }
                ProgressPoster(sentence: sentence)
                if let picture {
                    ShareLink(item: picture, preview: SharePreview(sentence, image: picture)) {
                        Text("Karte teilen")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.button, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(Color.white)
                    }
                }
                Spacer()
            }
            .padding(20)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { render() }
    }

    private func render() {
        let renderer = ImageRenderer(content: ProgressPoster(sentence: sentence))
        renderer.scale = 2
        if let uiImage = renderer.uiImage {
            picture = Image(uiImage: uiImage)
        }
    }
}

struct ProgressPoster: View {
    let sentence: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sprachduett")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            Text(ProgressShare.caption(sentence))
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
