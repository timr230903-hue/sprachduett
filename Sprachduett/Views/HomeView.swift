import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var help: HelpRouter
    @State private var playing = false
    @State private var together = true
    @State private var showDuo = false
    @State private var showSettings = false

    var body: some View {
        ScreenBackground {
            VStack(spacing: 22) {
                HStack {
                    Text("Sprachduett").font(.headline)
                    Spacer()
                    HelpButton()
                }
                Text(model.pathSnapshot.label)
                    .font(.title3.weight(.semibold))
                Text(model.pathSnapshot.unitTitle)
                    .foregroundStyle(.secondary)
                ProgressDots(done: model.pathSnapshot.unitIndex, total: model.pathSnapshot.unitCount)
                Spacer()
                Button {
                    together = true
                    playing = true
                } label: {
                    Text("Zusammen spielen")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(Theme.coral, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                HStack(spacing: 12) {
                    smallButton("Solo üben") { together = false; playing = true }
                    smallButton("Duo") { showDuo = true }
                    smallButton("Einstellungen") { showSettings = true }
                }
                Spacer()
            }
            .padding(24)
        }
        .fullScreenCover(isPresented: $playing) {
            RoundScreen(together: together)
        }
        .sheet(isPresented: $showDuo) { DuoView() }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProgressDots: View {
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Circle()
                    .fill(index < done ? Theme.leaf : Theme.mango.opacity(0.35))
                    .frame(width: 12, height: 12)
            }
        }
    }
}

struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var help: HelpRouter
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TutorialKey.lesson) private var lessonSeen = false
    @State private var name = ""

    var body: some View {
        NavigationStack {
            ScreenBackground {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { name = model.me.name }
                    FillButton(title: "Name sichern") {
                        model.updateProfile(name: name, gender: model.me.gender, emoji: model.me.emoji)
                    }
                    SoftButton(title: "Tutorial ansehen") {
                        lessonSeen = false
                        dismiss()
                        help.open()
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
