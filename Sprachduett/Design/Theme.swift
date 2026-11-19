import AudioToolbox
import SwiftUI
import UIKit

/// Ruhige Palette: warmes Creme, Tempelgold als einzige Akzentfarbe, Tinte in Nachtblau.
enum Theme {
    /// Tempelgold, im Hellen dunkel genug für Text, im Dunkeln hell genug auf Nachtblau.
    static let accent = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.93, green: 0.80, blue: 0.58, alpha: 1)
        }
        return UIColor(red: 0.26, green: 0.15, blue: 0.04, alpha: 1)
    })
    /// Knöpfe bleiben dunkel, damit weiße Schrift in beiden Modi lesbar ist.
    static let button = Color(red: 0.11, green: 0.14, blue: 0.20)
    static let navy = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.78, green: 0.84, blue: 0.93, alpha: 1)
        }
        return UIColor(red: 0.11, green: 0.14, blue: 0.20, alpha: 1)
    })
    static let sage = Color(red: 0.29, green: 0.45, blue: 0.38)
    static let brick = Color(red: 0.55, green: 0.32, blue: 0.28)
    static let coral = brick
    static let mango = accent
    static let leaf = sage
    static let ink = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.95, green: 0.93, blue: 0.89, alpha: 1)
        }
        return UIColor(red: 0.13, green: 0.16, blue: 0.22, alpha: 1)
    })
    static let cream = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        }
        return UIColor(red: 0.97, green: 0.95, blue: 0.91, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1)
        }
        return UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1)
    })
    static let radius: CGFloat = 22
}

struct ScreenBackground<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .foregroundStyle(Theme.ink)
            .background(Theme.cream.ignoresSafeArea())
    }
}

struct WarmCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

struct FillButton: View {
    let title: String
    var systemImage: String? = nil
    var color: Color = Theme.button
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(RaisedButtonStyle(color: color))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

struct RaisedButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded).weight(.heavy))
            .minimumScaleFactor(0.7)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .offset(y: configuration.isPressed ? 1 : 6)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(color)
                        .offset(y: configuration.isPressed ? 4 : 0)
                }
            )
            .padding(.bottom, 6)
    }
}

struct SoftButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(Theme.ink)
        }
        .buttonStyle(.plain)
    }
}

struct CloseBar: View {
    var title: String = "Zurück"
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text(title)
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zurück zum Start")
            .accessibilityIdentifier("close-screen")
            Spacer()
        }
    }
}

struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        DispatchQueue.main.async { controller.enable() }
    }

    final class Controller: UIViewController {
        func enable() {
            guard let navigation = navigationController else { return }
            navigation.interactivePopGestureRecognizer?.isEnabled = true
            navigation.interactivePopGestureRecognizer?.delegate = navigation
        }
    }
}

extension UINavigationController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1057)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        AudioServicesPlaySystemSound(1053)
    }
}
