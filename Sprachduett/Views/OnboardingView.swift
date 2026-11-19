import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(TutorialKey.intro) private var introSeen = false
    @State private var name = ""
    @State private var gender: SpeakerGender = .unspecified
    @State private var emoji = "🐘"
    private let emojis = ["🐘", "🌷", "🌊", "🦊", "🌙", "☀️"]

    var body: some View {
        if introSeen {
            profile
        } else {
            TutorialCarousel(onDone: {
                if model.me.name.isEmpty {
                    model.finishOnboarding(name: "Du", gender: .unspecified, emoji: model.me.emoji)
                }
                introSeen = true
            })
        }
    }

    private var profile: some View {
        ScreenBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Sprachduett")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Zwei Stimmen, eine Sprache. Ihr sagt die Zeilen laut zueinander, nicht in eure Handys.")
                        .foregroundStyle(.secondary)
                    TextField("Dein Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    Text("Wie sprichst du höflich?")
                        .font(.headline)
                    genderButton(.male, "ครับ khráp")
                    genderButton(.female, "ค่ะ khâ / คะ khá")
                    Text("Dein Zeichen")
                        .font(.headline)
                    emojiRow
                    FillButton(title: "Los geht's", systemImage: "heart.fill") {
                        model.finishOnboarding(name: name, gender: gender, emoji: emoji)
                    }
                    .disabled(gender == .unspecified || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(gender == .unspecified || name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                }
                .padding(20)
            }
        }
    }

    private var emojiRow: some View {
        HStack(spacing: 10) {
            ForEach(emojis, id: \.self) { item in
                Button {
                    emoji = item
                } label: {
                    Text(item)
                        .font(.largeTitle)
                        .padding(6)
                        .background(item == emoji ? Theme.mango.opacity(0.35) : Color.clear, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func genderButton(_ value: SpeakerGender, _ title: String) -> some View {
        Button {
            gender = value
        } label: {
            HStack {
                Text(title)
                Spacer()
                if gender == value {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.leaf)
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
