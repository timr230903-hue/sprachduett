import SwiftUI
import UIKit

@MainActor
final class HelpRouter: ObservableObject {
    @Published var showTutorial = false
    func open() { showTutorial = true }
}

@MainActor
final class ScreenTracker: ObservableObject {
    @Published var name = "Home"
}

struct ShakeCatcher: UIViewControllerRepresentable {
    var onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeController {
        let controller = ShakeController()
        controller.onShake = onShake
        return controller
    }

    func updateUIViewController(_ controller: ShakeController, context: Context) {
        controller.onShake = onShake
    }

    final class ShakeController: UIViewController {
        var onShake: () -> Void = {}
        override var canBecomeFirstResponder: Bool { true }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }
        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake { onShake() }
        }
    }
}

struct HelpButton: View {
    @EnvironmentObject private var help: HelpRouter

    var body: some View {
        Button(action: help.open) {
            Image(systemName: "questionmark.circle")
                .font(.title3)
                .foregroundStyle(Theme.accent)
        }
        .accessibilityLabel("Hilfe")
    }
}

struct TutorialCarousel: View {
    var onDone: () -> Void
    @State private var index = 0

    var body: some View {
        ScreenBackground {
            VStack(spacing: 12) {
                CloseBar(title: "Schließen", action: onDone)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                TabView(selection: $index) {
                    ForEach(Array(TutorialScript.pages.enumerated()), id: \.element.id) { item in
                        TutorialCard(page: item.element)
                            .tag(item.offset)
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                FillButton(title: TutorialScript.buttonTitle(index: index)) {
                    if let next = TutorialScript.advance(index: index) {
                        index = next
                    } else {
                        onDone()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct TutorialCard: View {
    let page: GuideCard

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(page.emoji).font(.system(size: 72))
            Text(page.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
            Text(page.text)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct LessonCoach: View {
    let step: Int
    let next: () -> Void

    var body: some View {
        let card = LessonTour.steps.indices.contains(step) ? LessonTour.steps[step] : LessonTour.steps[0]
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.28).ignoresSafeArea()
            WarmCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(card.emoji)  \(card.title)").font(.headline)
                    Text(card.text)
                    FillButton(title: LessonTour.buttonTitle(step: step), action: next)
                }
            }
            .padding(20)
        }
    }
}
