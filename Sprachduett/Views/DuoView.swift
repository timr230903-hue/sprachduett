import SwiftUI

struct DuoView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var sync: SyncHub
    @EnvironmentObject private var help: HelpRouter
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TutorialKey.lesson) private var lessonSeen = false
    @State private var name = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Wir")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        Text(sync.status.text).foregroundStyle(.secondary)
                        WarmCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(model.me.emoji)  \(model.me.name)")
                                    .font(.title3.weight(.semibold))
                                Text(particleLine).font(.subheadline).foregroundStyle(.secondary)
                                if let partner = model.partner {
                                    Text("\(partner.emoji)  \(partner.name) ist dabei")
                                } else {
                                    Text("Noch kein zweites iPhone. Allein üben geht über „Ein Handy weitergeben“.")
                                }
                            }
                        }
                        if model.partner == nil {
                            FillButton(title: busy ? "Einladung entsteht …" : "Duo erstellen und einladen", systemImage: "square.and.arrow.up") {
                                invite()
                            }
                            .disabled(busy || !sync.canShare)
                        }
                        if model.duo.members.count >= 2 {
                            SoftButton(title: "Rollen tauschen") { model.swapRoles() }
                        }
                        SoftButton(title: "Tutorial ansehen") {
                            lessonSeen = false
                            help.open()
                        }
                        Text("Dein Name")
                            .font(.headline)
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .onAppear { name = model.me.name }
                        FillButton(title: "Name sichern") {
                            model.updateProfile(name: name, gender: model.me.gender, emoji: model.me.emoji)
                        }
                        Text("Ein Duo ist eine private iCloud-Zone. Der Einladungslink kommt von Apple. Ohne iCloud bleibt alles auf diesem Gerät.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { CloseBar { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { HelpButton() }
            }
        }
    }

    private var particleLine: String {
        switch model.me.gender {
        case .male: return "Höflich mit ครับ khráp"
        case .female: return "Höflich mit ค่ะ khâ und คะ khá"
        case .unspecified: return "Noch keine Partikel gewählt"
        }
    }

    private func invite() {
        busy = true
        Task {
            do {
                let share = try await sync.makeShare()
                if let container = sync.container {
                    CloudSharingPresenter.present(share: share, container: container) { error in
                        Task { @MainActor in
                            sync.report(error, context: "Die Freigabe konnte nicht gesichert werden.")
                        }
                    }
                } else {
                    sync.report("Der iCloud-Container ist nicht da. Die Einladung kann nicht verschickt werden.")
                }
            } catch {
                sync.report(error, context: "Das Duo konnte nicht angelegt werden.")
            }
            busy = false
        }
    }
}
