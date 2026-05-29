//
//  SequencesView.swift
//  DailyMentalMath
//
//  Created by Esma Zuurbier on 29/05/2026.
//

import SwiftUI

struct SequencesView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Number Sequences")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .glassEffect(.regular, in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 36)

            Spacer()

            Text("Coming soon")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            Spacer()
        }
        .safeAreaPadding([.top, .bottom])
    }
}

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
        SequencesView(onBack: {})
    }
}
