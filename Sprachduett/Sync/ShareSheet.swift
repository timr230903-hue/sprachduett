import CloudKit
import SwiftUI
import UIKit

@MainActor
enum CloudSharingPresenter {
    private static var delegate: PresenterDelegate?

    static func present(share: CKShare, container: CKContainer, onError: @escaping (Error) -> Void) {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        let keeper = PresenterDelegate(onError: onError)
        delegate = keeper
        controller.delegate = keeper
        guard let top = topViewController() else {
            onError(ShareFailure.unavailable)
            return
        }
        controller.popoverPresentationController?.sourceView = top.view
        top.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        if controller == nil { controller = scene?.windows.first?.rootViewController }
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }

    final class PresenterDelegate: NSObject, UICloudSharingControllerDelegate {
        let onError: (Error) -> Void
        init(onError: @escaping (Error) -> Void) { self.onError = onError }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            DispatchQueue.main.async { self.onError(error) }
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { "Sprachduett" }
    }
}
