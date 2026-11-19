import SwiftUI
import UIKit

enum Theme {
    static let coral = Color(red: 0.86, green: 0.40, blue: 0.29)
    static let mango = Color(red: 0.93, green: 0.64, blue: 0.27)
    static let leaf = Color(red: 0.18, green: 0.52, blue: 0.40)
    static let cream = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.16, green: 0.12, blue: 0.11, alpha: 1)
        }
        return UIColor(red: 1, green: 0.96, blue: 0.93, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.23, green: 0.17, blue: 0.15, alpha: 1)
        }
        return UIColor.white
    })
    static let radius: CGFloat = 22
}

struct ScreenBackground<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
    var color: Color = Theme.coral
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
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
                .background(Theme.mango.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(Theme.coral)
        }
        .buttonStyle(.plain)
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
