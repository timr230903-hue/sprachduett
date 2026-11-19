import SwiftUI

struct RootView: View {
    @EnvironmentObject private var help: HelpRouter
    @State private var feedback = false
    @AppStorage(TutorialKey.intro) private var introSeen = false

    var body: some View {
        ShellView()
        .fullScreenCover(isPresented: Binding(get: { !introSeen }, set: { shown in
            if !shown { introSeen = true }
        })) {
            OnboardingView()
        }
        .sheet(isPresented: $help.showTutorial) {
            TutorialCarousel(onDone: { help.showTutorial = false })
        }
        .modifier(CloudAlert())
        .background(ShakeCatcher { feedback = true }.frame(width: 0, height: 0))
        .sheet(isPresented: $feedback) { FeedbackSheet() }
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
