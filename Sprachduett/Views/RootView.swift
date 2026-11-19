import SwiftUI

struct RootView: View {
    @EnvironmentObject private var help: HelpRouter
    @AppStorage(TutorialKey.intro) private var introSeen = false

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .fullScreenCover(isPresented: Binding(get: { !introSeen }, set: { _ in })) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $help.showTutorial) {
            TutorialCarousel(onDone: { help.showTutorial = false })
        }
        .modifier(CloudAlert())
    }
}

private struct CloudAlert: ViewModifier {
    @EnvironmentObject private var sync: SyncHub

    func body(content: Content) -> some View {
        content.alert(sync.alertTitle, isPresented: presented) {
            Button("OK") { sync.dismissAlert() }
        } message: {
            Text(sync.alertMessage ?? "")
        }
    }

    private var presented: Binding<Bool> {
        Binding(
            get: { sync.alertMessage != nil },
            set: { if !$0 { sync.dismissAlert() } }
        )
    }
}
