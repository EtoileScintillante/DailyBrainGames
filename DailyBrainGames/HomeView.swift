//
//  HomeView.swift
//  DailyBrainGames
//
//  Created by Esma Zuurbier on 29/05/2026.
//

import SwiftUI

struct HomeView: View {
    let onSelect: (GameRoute) -> Void
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Daily Brain Games")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Pick your training")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.top, 76)
            .padding(.bottom, 52)

            VStack(spacing: 16) {
                modeCard(
                    icon: "plus.forwardslash.minus",
                    title: "Arithmetic",
                    subtitle: "Addition, subtraction, multiplication & division",
                    route: .arithmetic,
                    enabled: true
                )

                modeCard(
                    icon: "target",
                    title: "Make Target",
                    subtitle: "Combine number cards to reach the target",
                    route: .makeTarget,
                    enabled: true
                )

                modeCard(
                    icon: "link",
                    title: "Number Chain",
                    subtitle: "Follow a chain of operations to find the answer or missing step",
                    route: .numberChain,
                    enabled: true
                )

                modeCard(
                    icon: "square.grid.3x3",
                    title: "Sequence",
                    subtitle: "Memorise and repeat the tile sequence",
                    route: .sequenceMemory,
                    enabled: true
                )

            }
            .padding(.horizontal, 20)

            Spacer()

            Menu {
                ForEach(Theme.allCases) { theme in
                    Button(action: { selectedTheme = theme }) {
                        Label(
                            theme.rawValue,
                            systemImage: selectedTheme == theme ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(selectedTheme.accent)
                        .frame(width: 10, height: 10)
                    Text("Theme")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: Capsule())
            }
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    func modeCard(
        icon: String,
        title: String,
        subtitle: String,
        route: GameRoute,
        enabled: Bool
    ) -> some View {
        Button {
            guard enabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(route)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(enabled ? .white : .white.opacity(0.35))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(enabled ? .white : .white.opacity(0.35))
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(enabled ? .white.opacity(0.65) : .white.opacity(0.25))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if enabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
        NavigationStack {
            HomeView { _ in }
        }
    }
}
