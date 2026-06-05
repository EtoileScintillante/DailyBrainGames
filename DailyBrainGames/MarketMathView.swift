//
//  MarketMathView.swift
//  DailyBrainGames
//
//  Created by Codex on 05/06/2026.
//

import SwiftUI

/// Difficulty presets for Market Math.
enum MarketMathDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }

    var basketName: String {
        switch self {
        case .easy: return "Power Core"
        case .medium: return "Industrial Pack"
        case .hard: return "Quantum Portfolio"
        }
    }

    var basketIcon: String {
        switch self {
        case .easy: return "bolt.fill"
        case .medium: return "gearshape.2.fill"
        case .hard: return "atom"
        }
    }

    var formula: String {
        switch self {
        case .easy: return "Energy × Metal"
        case .medium: return "(Energy × Metal) + Crystal"
        case .hard: return "(Energy × Metal) + (Crystal × Oil)"
        }
    }
}

/// A product that contributes to a basket's true value.
private enum MarketProduct: String, CaseIterable, Identifiable {
    case energy = "Energy"
    case metal = "Metal"
    case crystal = "Crystal"
    case oil = "Oil"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .energy: return "bolt.fill"
        case .metal: return "wrench.and.screwdriver.fill"
        case .crystal: return "diamond.fill"
        case .oil: return "drop.fill"
        }
    }
}

/// The final trading decision for a generated market.
private enum MarketDecision: String, CaseIterable {
    case sell = "SELL"
    case noTrade = "NO TRADE"
    case buy = "BUY"

    var color: Color {
        switch self {
        case .sell: return Color(red: 1.0, green: 0.35, blue: 0.35)
        case .noTrade: return Color(red: 1.0, green: 0.76, blue: 0.24)
        case .buy: return Color(red: 0.25, green: 0.88, blue: 0.48)
        }
    }
}

/// Optional event that modifies products or the final basket value.
private enum MarketEvent {
    case energySurge
    case metalShortage
    case energyTax
    case metalBoom
    case crystalSurge
    case roundUp
    case oilShortage
    case oilBoom
    case crystalTax
    case volatility(MarketProduct)
    case bullMarket
    case bearMarket

    var title: String {
        switch self {
        case .energySurge: return "Energy Surge"
        case .metalShortage: return "Metal Shortage"
        case .energyTax: return "Energy Tax"
        case .metalBoom: return "Metal Boom"
        case .crystalSurge: return "Crystal Surge"
        case .roundUp: return "Round Up"
        case .oilShortage: return "Oil Shortage"
        case .oilBoom: return "Oil Boom"
        case .crystalTax: return "Crystal Tax"
        case .volatility: return "Volatility Event"
        case .bullMarket: return "Bull Market"
        case .bearMarket: return "Bear Market"
        }
    }

    var detail: String {
        switch self {
        case .energySurge: return "Energy counts double"
        case .metalShortage: return "Metal counts half"
        case .energyTax: return "Subtract 5 from Energy"
        case .metalBoom: return "Metal counts 1.5×"
        case .crystalSurge: return "Crystal counts double"
        case .roundUp: return "Final value rounds up to the nearest 10"
        case .oilShortage: return "Oil counts half"
        case .oilBoom: return "Oil counts double"
        case .crystalTax: return "Subtract 20 from the final value"
        case .volatility(let product): return "\(product.rawValue) counts double"
        case .bullMarket: return "Add 20 to the final value"
        case .bearMarket: return "Subtract 20 from the final value"
        }
    }
}

/// A complete validated market shown for one decision round.
private struct MarketRound {
    let products: [MarketProduct: Int]
    let event: MarketEvent?
    let trueValue: Int
    let bid: Int
    let ask: Int
    let correctDecision: MarketDecision
}

/// Final statistics captured when a Market Math session ends.
private struct MarketMathSummary {
    let score: Int
    let correct: Int
    let averageDecisionTime: Double
    let bestDecisionTime: Double?
}

/// Fast decision game based on comparing a basket's true value with its market spread.
struct MarketMathView: View {
    let onBack: () -> Void

    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple
    @AppStorage("marketMathDifficulty") private var difficulty: MarketMathDifficulty = .easy
    @AppStorage("marketMathEventsEnabled") private var eventsEnabled: Bool = true
    @AppStorage("marketMathBestEasy") private var bestEasy: Int = 0
    @AppStorage("marketMathBestMedium") private var bestMedium: Int = 0
    @AppStorage("marketMathBestHard") private var bestHard: Int = 0

    @State private var phase: GamePhase = .ready
    @State private var market: MarketRound?
    @State private var score = 0
    @State private var strikes = 0
    @State private var correctDecisions = 0
    @State private var decisionTimes: [Double] = []
    @State private var bestDecisionTime: Double?
    @State private var roundStart = Date()
    @State private var timeRemaining = 30
    @State private var roundTimer: Timer?
    @State private var eventCooldown = 0
    @State private var decisionBag: [MarketDecision] = []
    @State private var decisionLocked = false
    @State private var feedback = ""
    @State private var feedbackColor: Color = .white
    @State private var showingHelp = false
    @State private var summary: MarketMathSummary?
    @State private var isVisible = false

    private enum GamePhase {
        case ready
        case playing
        case summary
    }

    private var activeBest: Int {
        switch difficulty {
        case .easy: return bestEasy
        case .medium: return bestMedium
        case .hard: return bestHard
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerArea

            switch phase {
            case .ready:
                readyArea
            case .playing:
                marketArea
            case .summary:
                summaryArea
            }
        }
        .safeAreaPadding([.top, .bottom])
        .overlay {
            if showingHelp {
                helpOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingHelp)
        .onAppear { isVisible = true }
        .onDisappear {
            isVisible = false
            invalidateTimer()
        }
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(spacing: 10) {
            ZStack {
                Text("Market Math")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        invalidateTimer()
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .glassEffect(.regular, in: Circle())
                    }

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .glassEffect(.regular, in: Circle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 28)

            HStack(spacing: 8) {
                difficultyMenu
                eventsButton
                stopButton
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)

            HStack(spacing: 0) {
                statView(label: "Score", value: "\(score)")
                statDivider
                statView(label: "Strikes", value: "\(strikes) / 3")
                statDivider
                statView(label: "Best", value: "\(activeBest)")
                statDivider
                statView(label: "Time", value: phase == .playing ? "\(timeRemaining)s" : "30s")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    private var difficultyMenu: some View {
        Menu {
            ForEach(MarketMathDifficulty.allCases) { option in
                Button(option.rawValue) {
                    difficulty = option
                    resetReadyState()
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(difficulty.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .glassEffect(.regular, in: Capsule())
        }
        .disabled(phase == .playing)
        .opacity(phase == .playing ? 0.4 : 1)
    }

    private var eventsButton: some View {
        Button {
            eventsEnabled.toggle()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(eventsEnabled ? selectedTheme.accent : Color.white.opacity(0.35))
                    .frame(width: 8, height: 8)
                Text("Events")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .glassEffect(.regular, in: Capsule())
            .overlay {
                if eventsEnabled {
                    Capsule().strokeBorder(selectedTheme.accent, lineWidth: 2)
                }
            }
        }
        .disabled(phase == .playing)
        .opacity(phase == .playing ? 0.4 : 1)
    }

    private var stopButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            endGame()
        } label: {
            Text("Stop")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .glassEffect(.regular, in: Capsule())
        }
        .disabled(phase != .playing)
        .opacity(phase == .playing ? 1 : 0.35)
    }

    // MARK: - Ready

    private var readyArea: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 54, weight: .semibold))
                .foregroundColor(selectedTheme.accent)

            VStack(spacing: 8) {
                Text(difficulty.basketName)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(difficulty.formula)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            Button {
                startGame()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
            }
            .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 13))
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Market

    private var marketArea: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(spacing: 12) {
                    ZStack {
                        Color.clear
                        if let event = market?.event {
                            eventBanner(event)
                        }
                    }
                    .frame(height: 70)

                    basketSection
                    productsSection
                    pricesSection

                    Text(feedback)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(feedbackColor)
                        .frame(height: 22)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)

            decisionButtons
                .padding(.bottom, 14)
        }
    }

    private var basketSection: some View {
        VStack(spacing: 5) {
            Label(difficulty.basketName, systemImage: difficulty.basketIcon)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(difficulty.formula)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    private var productsSection: some View {
        VStack(spacing: 8) {
            ForEach(productsForDifficulty, id: \.self) { product in
                HStack {
                    Label(product.rawValue, systemImage: product.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("\(market?.products[product] ?? 0)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    private var pricesSection: some View {
        HStack(spacing: 0) {
            priceView(label: "Bid", value: market?.bid ?? 0, color: MarketDecision.sell.color)
            statDivider
            priceView(label: "Ask", value: market?.ask ?? 0, color: MarketDecision.buy.color)
        }
        .padding(.vertical, 13)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    private var decisionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                decisionButton(.sell)
                decisionButton(.buy)
            }
            decisionButton(.noTrade)
        }
        .padding(.horizontal, 16)
    }

    private func decisionButton(_ decision: MarketDecision) -> some View {
        Button {
            submit(decision)
        } label: {
            Text(decision.rawValue)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    decision.color.opacity(0.34),
                    in: RoundedRectangle(cornerRadius: 13)
                )
        }
        .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(decision.color.opacity(0.9), lineWidth: 2)
        }
        .shadow(color: decision.color.opacity(0.18), radius: 7)
        .disabled(decisionLocked)
        .opacity(decisionLocked ? 0.45 : 1)
    }

    private func eventBanner(_ event: MarketEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title.uppercased())
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(event.detail)
                    .font(.system(size: 13, weight: .semibold))
            }
            Spacer()
        }
        .foregroundColor(.white)
        .padding(13)
        .background(Color.orange.opacity(0.32), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.orange.opacity(0.9), lineWidth: 2)
        }
        .shadow(color: .orange.opacity(0.45), radius: 10)
        .transition(.scale(scale: 0.94).combined(with: .opacity))
    }

    // MARK: - Summary

    private var summaryArea: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundColor(selectedTheme.accent)

                Text("Session Summary")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let summary {
                    VStack(spacing: 0) {
                        summaryRow("Final Score", "\(summary.score)")
                        summaryDivider
                        summaryRow("Correct Decisions", "\(summary.correct)")
                        summaryDivider
                        summaryRow("Average Decision Time", String(format: "%.1f sec", summary.averageDecisionTime))
                        summaryDivider
                        summaryRow(
                            "Best Decision Time",
                            summary.bestDecisionTime.map { String(format: "%.1f sec", $0) } ?? "—"
                        )
                    }
                    .padding(.horizontal, 16)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    closeSummary()
                } label: {
                    Text("Close")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                }
                .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 13))
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Help

    private var helpOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { showingHelp = false }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Button {
                            showingHelp = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(9)
                                .glassEffect(.regular, in: Circle())
                        }
                        Spacer()
                        Text("How to Play")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Color.clear.frame(width: 31, height: 31)
                    }

                    helpRule("Goal", "Calculate the basket's true value using the formula and find profitable trades.")
                    helpRule("BUY", "True Value > Ask")
                    helpRule("SELL", "True Value < Bid")
                    helpRule("NO TRADE", "Bid ≤ True Value ≤ Ask")
                    helpRule("Scoring", "Correct decisions earn 10 points plus a speed bonus.")
                    helpRule("Round Timer", "You have 30 seconds. Timeout adds a strike.")
                    helpRule("Game Over", "Three strikes ends the session.")
                    helpRule("Market Events", "Events modify products or the final basket value. Take them into account before trading.")
                }
                .padding(18)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 18)
                .padding(.vertical, 60)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Game Flow

    private func startGame() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        invalidateTimer()
        score = 0
        strikes = 0
        correctDecisions = 0
        decisionTimes = []
        bestDecisionTime = nil
        eventCooldown = 0
        decisionBag = []
        summary = nil
        phase = .playing
        loadNextMarket()
    }

    private func loadNextMarket() {
        guard phase == .playing, isVisible else { return }

        decisionLocked = false
        feedback = ""
        timeRemaining = 30

        let intendedDecision = nextBalancedDecision()
        let event = nextEvent()
        market = generateMarket(difficulty: difficulty, event: event, intendedDecision: intendedDecision)
        roundStart = Date()
        startRoundTimer()
    }

    private func submit(_ decision: MarketDecision) {
        guard phase == .playing, !decisionLocked, let market else { return }

        decisionLocked = true
        invalidateTimer()
        let elapsed = min(30, Date().timeIntervalSince(roundStart))
        decisionTimes.append(elapsed)

        if decision == market.correctDecision {
            let bonus = speedBonus(for: elapsed)
            score += 10 + bonus
            correctDecisions += 1
            bestDecisionTime = min(bestDecisionTime ?? elapsed, elapsed)
            feedback = bonus > 0 ? "Correct  +\(10 + bonus)" : "Correct  +10"
            feedbackColor = selectedTheme.accent
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            strikes += 1
            feedback = "Strike — \(market.correctDecision.rawValue)"
            feedbackColor = MarketDecision.sell.color
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        finishRoundAfterFeedback()
    }

    private func handleTimeout() {
        guard phase == .playing, !decisionLocked else { return }

        decisionLocked = true
        invalidateTimer()
        decisionTimes.append(30)
        strikes += 1
        feedback = "Time out — Strike"
        feedbackColor = MarketDecision.sell.color
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        finishRoundAfterFeedback()
    }

    private func finishRoundAfterFeedback() {
        if strikes >= 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                endGame()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                loadNextMarket()
            }
        }
    }

    private func endGame() {
        guard phase == .playing else { return }
        invalidateTimer()

        let average = decisionTimes.isEmpty ? 0 : decisionTimes.reduce(0, +) / Double(decisionTimes.count)

        summary = MarketMathSummary(
            score: score,
            correct: correctDecisions,
            averageDecisionTime: average,
            bestDecisionTime: bestDecisionTime
        )
        updateBestScore()
        phase = .summary
    }

    private func closeSummary() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        score = 0
        strikes = 0
        market = nil
        summary = nil
        timeRemaining = 30
        phase = .ready
    }

    private func resetReadyState() {
        guard phase != .playing else { return }
        score = 0
        strikes = 0
        summary = nil
        phase = .ready
    }

    // MARK: - Timer

    private func startRoundTimer() {
        invalidateTimer()
        roundTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                handleTimeout()
            }
        }
    }

    private func invalidateTimer() {
        roundTimer?.invalidate()
        roundTimer = nil
    }

    private func speedBonus(for seconds: Double) -> Int {
        switch seconds {
        case ..<5: return 10
        case ..<10: return 7
        case ..<15: return 4
        case ..<22: return 1
        default: return 0
        }
    }

    // MARK: - Generation

    private var productsForDifficulty: [MarketProduct] {
        switch difficulty {
        case .easy: return [.energy, .metal]
        case .medium: return [.energy, .metal, .crystal]
        case .hard: return [.energy, .metal, .crystal, .oil]
        }
    }

    private func nextBalancedDecision() -> MarketDecision {
        if decisionBag.isEmpty {
            decisionBag = MarketDecision.allCases.shuffled()
        }
        return decisionBag.removeFirst()
    }

    private func nextEvent() -> MarketEvent? {
        guard eventsEnabled else { return nil }

        if eventCooldown > 0 {
            eventCooldown -= 1
            return nil
        }

        guard Double.random(in: 0..<1) < 0.30 else { return nil }
        eventCooldown = 2
        return randomEvent(for: difficulty)
    }

    private func randomEvent(for difficulty: MarketMathDifficulty) -> MarketEvent {
        var events: [MarketEvent] = [
            .energySurge,
            .metalShortage
        ]

        if difficulty != .easy {
            events += [
                .energyTax,
                .metalBoom,
                .crystalSurge,
                .roundUp
            ]
        }

        if difficulty == .hard {
            events += [
                .oilShortage,
                .oilBoom,
                .crystalTax,
                .volatility(productsForDifficulty.randomElement() ?? .energy),
                .bullMarket,
                .bearMarket
            ]
        }

        return events.randomElement() ?? .energySurge
    }

    private func generateMarket(
        difficulty: MarketMathDifficulty,
        event: MarketEvent?,
        intendedDecision: MarketDecision
    ) -> MarketRound {
        for _ in 0..<500 {
            let products = generateProducts(difficulty: difficulty, event: event)
            let trueValue = calculateValue(difficulty: difficulty, products: products, event: event)

            guard trueValue > 0 else { continue }
            if difficulty == .hard && trueValue > 600 { continue }

            let prices = generatePrices(trueValue: trueValue, decision: intendedDecision)
            guard prices.bid < prices.ask else { continue }
            guard validates(
                trueValue: trueValue,
                bid: prices.bid,
                ask: prices.ask,
                decision: intendedDecision
            ) else { continue }

            return MarketRound(
                products: products,
                event: event,
                trueValue: trueValue,
                bid: prices.bid,
                ask: prices.ask,
                correctDecision: intendedDecision
            )
        }

        let fallback: [MarketProduct: Int] = [
            .energy: 10,
            .metal: 10,
            .crystal: 10,
            .oil: 10
        ]
        let trueValue = calculateValue(difficulty: difficulty, products: fallback, event: nil)
        let prices = generatePrices(trueValue: trueValue, decision: intendedDecision)
        return MarketRound(
            products: fallback,
            event: nil,
            trueValue: trueValue,
            bid: prices.bid,
            ask: prices.ask,
            correctDecision: intendedDecision
        )
    }

    private func generateProducts(
        difficulty: MarketMathDifficulty,
        event: MarketEvent?
    ) -> [MarketProduct: Int] {
        var products: [MarketProduct: Int] = [
            .energy: Int.random(in: 5...20),
            .metal: Int.random(in: 5...20)
        ]

        if difficulty != .easy {
            products[.crystal] = Int.random(in: difficulty == .medium ? 5...40 : 5...20)
        }
        if difficulty == .hard {
            products[.oil] = Int.random(in: 5...20)
        }

        switch event {
        case .metalShortage, .metalBoom:
            products[.metal] = randomEven(in: 6...20)
        case .oilShortage:
            products[.oil] = randomEven(in: 6...20)
        default:
            break
        }

        return products
    }

    private func calculateValue(
        difficulty: MarketMathDifficulty,
        products: [MarketProduct: Int],
        event: MarketEvent?
    ) -> Int {
        var energy = products[.energy] ?? 0
        var metal = products[.metal] ?? 0
        var crystal = products[.crystal] ?? 0
        var oil = products[.oil] ?? 0

        switch event {
        case .energySurge:
            energy *= 2
        case .metalShortage:
            metal /= 2
        case .energyTax:
            energy -= 5
        case .metalBoom:
            metal = metal * 3 / 2
        case .crystalSurge:
            crystal *= 2
        case .oilShortage:
            oil /= 2
        case .oilBoom:
            oil *= 2
        case .volatility(let product):
            switch product {
            case .energy: energy *= 2
            case .metal: metal *= 2
            case .crystal: crystal *= 2
            case .oil: oil *= 2
            }
        default:
            break
        }

        var value: Int
        switch difficulty {
        case .easy:
            value = energy * metal
        case .medium:
            value = energy * metal + crystal
        case .hard:
            value = energy * metal + crystal * oil
        }

        switch event {
        case .roundUp:
            value = ((value + 9) / 10) * 10
        case .crystalTax:
            value -= 20
        case .bullMarket:
            value += 20
        case .bearMarket:
            value -= 20
        default:
            break
        }

        return value
    }

    private func generatePrices(
        trueValue: Int,
        decision: MarketDecision
    ) -> (bid: Int, ask: Int) {
        let maxGap = max(3, min(16, trueValue / 12))
        let opportunityGap = Int.random(in: 2...maxGap)
        let spread = Int.random(in: 2...max(3, min(10, maxGap)))

        switch decision {
        case .buy:
            let ask = trueValue - opportunityGap
            return (ask - spread, ask)
        case .sell:
            let bid = trueValue + opportunityGap
            return (bid, bid + spread)
        case .noTrade:
            let below = Int.random(in: 1...max(1, spread))
            let above = Int.random(in: 1...max(1, spread))
            return (trueValue - below, trueValue + above)
        }
    }

    private func validates(
        trueValue: Int,
        bid: Int,
        ask: Int,
        decision: MarketDecision
    ) -> Bool {
        guard bid < ask else { return false }
        switch decision {
        case .buy: return trueValue > ask
        case .sell: return trueValue < bid
        case .noTrade: return bid <= trueValue && trueValue <= ask
        }
    }

    private func randomEven(in range: ClosedRange<Int>) -> Int {
        let values = range.filter { $0.isMultiple(of: 2) }
        return values.randomElement() ?? range.lowerBound
    }

    private func updateBestScore() {
        switch difficulty {
        case .easy:
            bestEasy = max(bestEasy, score)
        case .medium:
            bestMedium = max(bestMedium, score)
        case .hard:
            bestHard = max(bestHard, score)
        }
    }

    // MARK: - Small Views

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.20))
            .frame(width: 1, height: 28)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(height: 1)
    }

    private func statView(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private func priceView(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Text("\(value)")
                .font(.system(size: 27, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private func helpRule(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(selectedTheme.accent)
            Text(detail)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
        MarketMathView(onBack: {})
    }
}
