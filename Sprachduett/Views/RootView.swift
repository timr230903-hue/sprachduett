import SwiftUI

enum AppTab: Hashable {
    case today, duets, words, us
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: AppTab = .today

    var body: some View {
        TabView(selection: $tab) {
            HomeView(openDuets: { tab = .duets })
                .tabItem { Label("Heute", systemImage: "sun.max.fill") }
                .tag(AppTab.today)
            SceneListView()
                .tabItem { Label("Duette", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppTab.duets)
            WordsView()
                .tabItem { Label("Wörter", systemImage: "text.book.closed.fill") }
                .tag(AppTab.words)
            DuoView()
                .tabItem { Label("Wir", systemImage: "person.2.fill") }
                .tag(AppTab.us)
        }
        .fullScreenCover(isPresented: Binding(get: { !model.onboarded }, set: { _ in })) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
    }
}
