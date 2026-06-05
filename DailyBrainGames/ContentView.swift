//
//  ContentView.swift
//  DailyBrainGames
//
//  Created by Esma Zuurbier on 27/05/2026.
//

import SwiftUI
import UIKit

/// The top-level screens that can be pushed from Home.
///
/// Each case is a sibling route, so the navigation stack is always
/// `Home -> selected game` instead of game screens nesting inside each other.
enum GameRoute: Hashable {
    case arithmetic
    case makeTarget
    case marketMath
    case numberChain
    case sequenceMemory
}

/// Root view for the app.
///
/// Owns the single `NavigationStack` and its path so Home can push any game
/// directly while every game still swipes or dismisses back to Home.
struct ContentView: View {
    @State private var path: [GameRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScreenBackground {
                HomeView { route in
                    path = [route]
                }
                    .navigationDestination(for: GameRoute.self) { route in
                        GameDestinationView(route: route)
                    }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct GameDestinationView: View {
    let route: GameRoute
    @Environment(\.dismiss) private var dismiss
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        ScreenBackground {
            Group {
                switch route {
                case .arithmetic:
                    ArithmeticView {
                        dismiss()
                    }
                case .makeTarget:
                    MakeTargetView {
                        dismiss()
                    }
                case .marketMath:
                    MarketMathView {
                        dismiss()
                    }
                case .numberChain:
                    NumberChainView {
                        dismiss()
                    }
                case .sequenceMemory:
                    SequenceMemoryView {
                        dismiss()
                    }
                }
            }
        }
        .offset(x: dragOffset)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: dragOffset)
        .gesture(swipeToDismissGesture)
        .background(SwipeBackEnabler())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var swipeToDismissGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                guard value.translation.width > 0,
                      abs(value.translation.height) < 80 else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard value.translation.width > 120,
                      value.predictedEndTranslation.width > 180,
                      abs(value.translation.height) < 100 else { return }
                dismiss()
            }
    }
}

/// Applies the active theme wallpaper behind a screen.
///
/// This wrapper is used for Home and game destinations so pushed screens have
/// their own full background while still participating in native navigation.
private struct ScreenBackground<Content: View>: View {
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
            if let uiImage = UIImage(named: selectedTheme.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            content
        }
    }
}

/// Re-enables UIKit's interactive pop gesture when the SwiftUI navigation bar is hidden.
///
/// Hiding the navigation bar can disable the standard edge swipe in some
/// navigation controller configurations. This bridge keeps the custom in-game
/// headers while restoring the expected iOS back-swipe behavior.
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let navigationController = uiViewController.navigationController else { return }
            context.coordinator.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController else { return false }
            return navigationController.viewControllers.count > 1
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

#Preview {
    ContentView()
}
