import SwiftUI

struct WordsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wörter")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        NavigationLink {
                            TonesView()
                        } label: {
                            WarmCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Die fünf Töne").font(.headline)
                                    Text("Mittel, tief, fallend, hoch, steigend.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        ForEach(model.catalog.topics) { topic in
                            NavigationLink {
                                TopicView(topic: topic)
                            } label: {
                                WarmCard {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(topic.title).font(.headline)
                                        Text("\(topic.items.count) Wörter")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

struct TonesView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var coach: SpeechCoach

    var body: some View {
        ScreenBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.catalog.tones) { tone in
                        ToneCard(tone: tone) { coach.speak(tone.exampleThai) }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Töne")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ToneCard: View {
    let tone: ToneLesson
    let play: () -> Void

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(tone.nameDE).font(.headline)
                Text("\(tone.nameTH)  \(tone.roman)").foregroundStyle(.secondary)
                Text(tone.contour)
                Text(tone.exampleThai)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("\(tone.exampleRoman)  ·  \(tone.exampleDE)")
                Text(tone.rule).font(.footnote).foregroundStyle(.secondary)
                SoftButton(title: "Anhören", action: play)
            }
        }
    }
}

struct TopicView: View {
    let topic: Topic
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var coach: SpeechCoach

    var body: some View {
        ScreenBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(topic.blurb).foregroundStyle(.secondary)
                    ForEach(topic.items) { item in
                        PhraseRow(item: item, gender: model.me.gender) {
                            let spoken = Particles.apply(
                                thai: item.thai, roman: item.roman, particle: item.particle, gender: model.me.gender
                            )
                            coach.speak(spoken.thai)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PhraseRow: View {
    let item: Phrase
    let gender: SpeakerGender
    let play: () -> Void

    var body: some View {
        let spoken = Particles.apply(thai: item.thai, roman: item.roman, particle: item.particle, gender: gender)
        WarmCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(spoken.thai).font(.title3.weight(.semibold))
                    Text(spoken.roman)
                    Text(item.german).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: play) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(Theme.coral)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
