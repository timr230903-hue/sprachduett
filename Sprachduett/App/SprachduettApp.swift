import CloudKit
import SwiftUI
import UIKit

@main
struct SprachduettApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var sync = SyncHub.shared
    @StateObject private var coach = SpeechCoach()
    @StateObject private var help = HelpRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.coral)
                .environmentObject(model)
                .environmentObject(sync)
                .environmentObject(coach)
                .environmentObject(help)
                .task {
                    coach.refreshAvailability()
                    await sync.start(model: model)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await sync.syncNow() }
                    }
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if CloudConfig.isCompiledIn {
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        await SyncHub.shared.syncNow()
        return .newData
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata { accept(metadata) }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        accept(cloudKitShareMetadata)
    }

    private func accept(_ metadata: CKShare.Metadata) {
        guard CloudConfig.isCompiledIn else { return }
        Task { @MainActor in await SyncHub.shared.accept(metadata) }
    }
}
