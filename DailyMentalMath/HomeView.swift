//
//  HomeView.swift
//  DailyMentalMath
//
//  Created by Esma Zuurbier on 29/05/2026.
//

import SwiftUI

struct HomeView: View {
    let onSelect: (AppScreen) -> Void
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Daily Mental Math")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Choose your training")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(.top, 96)
            .padding(.bottom, 52)

            VStack(spacing: 16) {
                modeCard(
                    icon: "plus.forwardslash.minus",
                    title: "Arithmetic",
                    subtitle: "Addition, subtraction, multiplication & division",
                    enabled: true
                ) {
                    onSelect(.arithmetic)
                }

                modeCard(
                    icon: "ellipsis",
                    title: "Number Sequences",
                    subtitle: "Find the pattern and complete the sequence",
                    enabled: false
                ) {}
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
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
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
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .glassEffect(enabled ? .regular.interactive(true) : .regular, in: RoundedRectangle(cornerRadius: 20))
        }
        .disabled(!enabled)
    }
}

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
        HomeView(onSelect: { _ in })
    }
}
