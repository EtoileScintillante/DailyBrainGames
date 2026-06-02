//
//  ContentView.swift
//  DailyBrainGames
//
//  Created by Esma Zuurbier on 27/05/2026.
//

import SwiftUI

enum AppScreen: Equatable {
    case home, arithmetic, makeTarget, numberChain, sequenceMemory
}

struct ContentView: View {
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple
    @State private var screen: AppScreen = .home

    var body: some View {
        ZStack {
            // Shared wallpaper background — rendered once, behind all screens
            Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
            if let uiImage = UIImage(named: selectedTheme.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }

            // Screen routing — slide left/right like native push navigation
            ZStack {
                if screen == .home {
                    HomeView { selected in
                        withAnimation(.easeInOut(duration: 0.3)) { screen = selected }
                    }
                    .transition(.move(edge: .leading))
                }
                if screen == .arithmetic {
                    ArithmeticView {
                        withAnimation(.easeInOut(duration: 0.3)) { screen = .home }
                    }
                    .transition(.move(edge: .trailing))
                }
                if screen == .makeTarget {
                    MakeTargetView {
                        withAnimation(.easeInOut(duration: 0.3)) { screen = .home }
                    }
                    .transition(.move(edge: .trailing))
                }
                if screen == .numberChain {
                    NumberChainView {
                        withAnimation(.easeInOut(duration: 0.3)) { screen = .home }
                    }
                    .transition(.move(edge: .trailing))
                }
                if screen == .sequenceMemory {
                    SequenceMemoryView {
                        withAnimation(.easeInOut(duration: 0.3)) { screen = .home }
                    }
                    .transition(.move(edge: .trailing))
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
