import SwiftUI

struct SceneListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pending: DuettScene?
    @State private var activeID: String?

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Duette")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        Text("Jede Szene gehört euch beiden. Auf deinem Handy stehen nur deine Zeilen.")
                            .foregroundStyle(.secondary)
                        ForEach(model.catalog.scenes) { scene in
                            Button {
                                pending = scene
                            } label: {
                                SceneRow(scene: scene, done: model.progress(for: scene))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { HelpButton() } }
            .navigationDestination(item: $activeID) { id in
                SessionView(sceneID: id)
            }
            .sheet(item: $pending) { scene in
                ModeSheet(scene: scene) { passPhone in
                    model.start(scene: scene, passPhone: passPhone)
                    pending = nil
                    activeID = scene.id
                }
            }
        }
    }
}

struct SceneRow: View {
    let scene: DuettScene
    let done: Int

    var body: some View {
        WarmCard {
            HStack(spacing: 12) {
                Text(scene.emoji).font(.largeTitle)
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.title).font(.headline)
                    Text("\(scene.roleA) und \(scene.roleB)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(done) von \(scene.lines.count) Zeilen")
                        .font(.caption)
                        .foregroundStyle(Theme.leaf)
                }
                Spacer()
            }
        }
    }
}

struct ModeSheet: View {
    let scene: DuettScene
    let start: (Bool) -> Void

    var body: some View {
        ScreenBackground {
            VStack(alignment: .leading, spacing: 16) {
                Text(scene.emoji).font(.largeTitle)
                Text(scene.title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text(scene.setting)
                    .foregroundStyle(.secondary)
                FillButton(title: "Zwei Handys", systemImage: "iphone") { start(false) }
                SoftButton(title: "Ein Handy weitergeben") { start(true) }
                Spacer()
            }
            .padding(20)
        }
        .presentationDetents([.medium])
    }
}
