//
//  MakeTargetView.swift
//  DailyMentalMath
//
//  Created by Esma Zuurbier on 31/05/2026.
//

import SwiftUI

struct MakeTargetView: View {
    let onBack: () -> Void

    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple
    @AppStorage("makeTargetDifficulty") private var difficulty: MakeTargetDifficulty = .easy
    @State private var puzzle: MakeTargetPuzzle? = nil
    @State private var cards: [MakeTargetCard] = []
    @State private var selectedCardIDs: [UUID] = []
    @State private var selectedOperator: String? = nil
    @State private var cardHistory: [[MakeTargetCard]] = []
    @State private var gamePhase: GamePhase = .playing
    @State private var showingHelp: Bool = false

    private enum GamePhase { case playing, solved, showingSolution }

    private var isDivisionByZero: Bool {
        guard selectedOperator == "÷",
              selectedCardIDs.count == 2,
              let id2 = selectedCardIDs.last,
              let card2 = cards.first(where: { $0.id == id2 })
        else { return false }
        return card2.value == 0
    }

    private var canSubmit: Bool {
        switch gamePhase {
        case .playing: return selectedCardIDs.count == 2 && selectedOperator != nil && !isDivisionByZero
        case .solved, .showingSolution: return true
        }
    }

    private var showIncorrect: Bool {
        gamePhase == .playing && cards.count == 1 && cards.first?.value != puzzle?.target
    }

    private var expressionPreview: String {
        let c1: MakeTargetCard? = selectedCardIDs.count > 0
            ? cards.first(where: { $0.id == selectedCardIDs[0] }) : nil
        let c2: MakeTargetCard? = selectedCardIDs.count > 1
            ? cards.first(where: { $0.id == selectedCardIDs[1] }) : nil

        if let a = c1, let op = selectedOperator, let b = c2 {
            if op == "÷" && b.value == 0 {
                return "\(a.expression) ÷ 0  ✗"
            }
            return "(\(a.expression) \(op) \(b.expression)) = \(compute(a.value, op, b.value))"
        } else if let a = c1, let op = selectedOperator {
            return "\(a.expression) \(op) ?"
        } else if let a = c1, let b = c2 {
            return "\(a.expression) ? \(b.expression)"
        } else if let a = c1 {
            return a.expression
        }
        return " "
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerArea
            mainArea
            controlsArea
        }
        .safeAreaPadding([.top, .bottom])
        .overlay {
            if showingHelp {
                helpOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingHelp)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { generateNewPuzzle() }
        }
    }

    // MARK: - Header

    var headerArea: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Make Target")
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
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) { showingHelp = true }
                    }) {
                        Image(systemName: "questionmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .glassEffect(.regular, in: Circle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 36)
            .padding(.bottom, 12)

            HStack {
                pickerMenu(title: difficulty.rawValue, options: MakeTargetDifficulty.allCases) { diff in
                    difficulty = diff
                    generateNewPuzzle()
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    func pickerMenu<T: Identifiable & RawRepresentable>(
        title: String,
        options: [T],
        onSelect: @escaping (T) -> Void
    ) -> some View where T.RawValue == String {
        Menu {
            ForEach(options) { option in
                Button(option.rawValue) { onSelect(option) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: Capsule())
        }
    }

    // MARK: - Main

    var mainArea: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 4) {
                Text("Target")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                Text(puzzle != nil ? "\(puzzle!.target)" : " ")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(puzzle != nil ? 1 : 0)
            }

            Spacer()

            HStack(spacing: 12) {
                ForEach(cards) { card in
                    cardView(card: card)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 95)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: cards.map(\.id))

            Spacer(minLength: 16)

            Text(expressionPreview)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(isDivisionByZero ? Color(red: 1.0, green: 0.35, blue: 0.35) : .white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .padding(.horizontal, 20)

            Spacer(minLength: 8)

            statusView
                .frame(minHeight: 28)

            Spacer(minLength: 0)
                .frame(maxHeight: 20)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    var statusView: some View {
        if gamePhase == .solved {
            Text("Correct ✓")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(selectedTheme.accent)
        } else if gamePhase == .showingSolution {
            Text("Solution: \n\(puzzle?.solutionExpression ?? "")")
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundColor(.orange)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
        } else if showIncorrect {
            Text("Incorrect!")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
        } else {
            Text(" ")
                .font(.system(size: 20, weight: .semibold))
        }
    }

    // MARK: - Controls

    var controlsArea: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(difficulty.allowedOperators, id: \.self) { op in
                    operatorButton(op)
                }
            }
            .padding(.horizontal, 16)

            Button(action: pressEnter) {
                Text("→")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .foregroundColor(canSubmit ? .white : .white.opacity(0.25))
            }
            .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 13))
            .disabled(!canSubmit)
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                bottomButton("Undo") { undoAction() }
                    .disabled(cardHistory.isEmpty || gamePhase != .playing)
                    .opacity(cardHistory.isEmpty || gamePhase != .playing ? 0.35 : 1)

                bottomButton("Reset") { resetPuzzle() }

                Spacer()

                bottomButton("Show Solution") { showSolution() }
                    .disabled(gamePhase != .playing)
                    .opacity(gamePhase != .playing ? 0.35 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Help Overlay

    @ViewBuilder
    var helpOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { showingHelp = false }
                }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) { showingHelp = false }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(9)
                            .glassEffect(.regular, in: Circle())
                    }
                    Spacer()
                    Text("How to Play")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .opacity(0)
                        .padding(9)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 12) {
                    helpStep("1.", "You get 4 number cards and a target number.")
                    helpStep("2.", "Select two cards and an operator in any order.")
                    helpStep("3.", "Press → to combine them into one new card.")
                    helpStep("4.", "Repeat until one card remains: it must equal the target.")
                    helpStep("5.", "Undo to go back, Reset for a new puzzle, or Show Solution if stuck.")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 20)
        }
    }

    func helpStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(selectedTheme.accent)
                .frame(width: 20, alignment: .leading)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Card & Operator Views

    func cardView(card: MakeTargetCard) -> some View {
        let isSelected = selectedCardIDs.contains(card.id)
        let shape = RoundedRectangle(cornerRadius: 16)

        return Button(action: {
            guard gamePhase == .playing else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            toggleCard(card)
        }) {
            Text("\(card.value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(minWidth: 72)
                .frame(height: 88)
        }
        .glassEffect(isSelected ? .regular.interactive(true) : .regular, in: shape)
        .overlay {
            if isSelected {
                shape.strokeBorder(selectedTheme.accent, lineWidth: 2.5)
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .opacity(gamePhase == .playing ? 1 : 0.35)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        .disabled(gamePhase != .playing)
    }

    func operatorButton(_ op: String) -> some View {
        let isSelected = selectedOperator == op
        let shape = RoundedRectangle(cornerRadius: 13)

        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedOperator = isSelected ? nil : op
        }) {
            Text(op)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .foregroundColor(.white)
        }
        .glassEffect(isSelected ? .regular.interactive(true) : .regular, in: shape)
        .overlay {
            if isSelected {
                shape.strokeBorder(selectedTheme.accent, lineWidth: 2)
            }
        }
        .opacity(gamePhase == .playing ? 1 : 0.35)
        .disabled(gamePhase != .playing)
    }

    func bottomButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .glassEffect(.regular, in: Capsule())
        }
    }

    // MARK: - Actions

    private func toggleCard(_ card: MakeTargetCard) {
        if let idx = selectedCardIDs.firstIndex(of: card.id) {
            selectedCardIDs.remove(at: idx)
        } else if selectedCardIDs.count < 2 {
            selectedCardIDs.append(card.id)
        }
    }

    private func pressEnter() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch gamePhase {
        case .playing: submitCombination()
        case .solved, .showingSolution: generateNewPuzzle()
        }
    }

    private func submitCombination() {
        guard selectedCardIDs.count == 2,
              let op = selectedOperator,
              let card1 = cards.first(where: { $0.id == selectedCardIDs[0] }),
              let card2 = cards.first(where: { $0.id == selectedCardIDs[1] }),
              !(op == "÷" && card2.value == 0)
        else { return }

        let newCard = MakeTargetCard(
            value: compute(card1.value, op, card2.value),
            expression: "(\(card1.expression) \(op) \(card2.expression))"
        )

        cardHistory.append(cards)

        let pos1 = cards.firstIndex(where: { $0.id == selectedCardIDs[0] }) ?? 0
        let pos2 = cards.firstIndex(where: { $0.id == selectedCardIDs[1] }) ?? 0
        let insertPos = min(pos1, pos2)

        var updated = cards.filter { $0.id != selectedCardIDs[0] && $0.id != selectedCardIDs[1] }
        updated.insert(newCard, at: min(insertPos, updated.count))

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { cards = updated }
        selectedCardIDs = []
        selectedOperator = nil

        if updated.count == 1, updated[0].value == puzzle?.target {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: 0.2)) { gamePhase = .solved }
        }
    }

    private func undoAction() {
        guard !cardHistory.isEmpty, gamePhase == .playing else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            cards = cardHistory.removeLast()
        }
        selectedCardIDs = []
        selectedOperator = nil
    }

    private func resetPuzzle() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        generateNewPuzzle()
    }

    private func showSolution() {
        guard gamePhase == .playing else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedCardIDs = []
        selectedOperator = nil
        withAnimation(.easeInOut(duration: 0.2)) { gamePhase = .showingSolution }
    }

    private func generateNewPuzzle() {
        let (newPuzzle, numbers) = MakeTargetView.generate(difficulty: difficulty)
        withAnimation(.easeInOut(duration: 0.25)) {
            puzzle = newPuzzle
            cards = numbers.map { MakeTargetCard(value: $0) }
        }
        cardHistory = []
        selectedCardIDs = []
        selectedOperator = nil
        gamePhase = .playing
    }

    private func compute(_ a: Int, _ op: String, _ b: Int) -> Int {
        switch op {
        case "+": return a + b
        case "−": return a - b
        case "×": return a * b
        case "÷":
            guard b != 0 else { return 0 }
            return Int((Double(a) / Double(b)).rounded())
        default: return 0
        }
    }

    // MARK: - Puzzle Generation

    static func generate(difficulty: MakeTargetDifficulty) -> (MakeTargetPuzzle, [Int]) {
        switch difficulty {
        case .easy:   return generateEasy()
        case .medium: return generateMedium()
        case .hard:   return generateHard()
        }
    }

    // Returns nil if the operation is invalid (zero division, unclean division, or overflow)
    private static func applyOp(_ a: Int, _ op: String, _ b: Int) -> Int? {
        switch op {
        case "+":
            let r = a + b
            return abs(r) <= 5000 ? r : nil
        case "−":
            let r = a - b
            return abs(r) <= 5000 ? r : nil
        case "×":
            let r = a * b
            return abs(r) <= 5000 ? r : nil
        case "÷":
            guard b != 0, a % b == 0 else { return nil }
            return a / b
        default: return nil
        }
    }

    private static func generateEasy() -> (MakeTargetPuzzle, [Int]) {
        for _ in 0..<500 {
            let nums = Array(Array(1...15).shuffled().prefix(4))

            var ops: [String]
            repeat {
                ops = (0..<3).map { _ in Bool.random() ? "+" : "−" }
            } while !ops.contains("+") || !ops.contains("−")

            let v1 = ops[0] == "+" ? nums[0] + nums[1] : nums[0] - nums[1]
            let v2 = ops[1] == "+" ? v1 + nums[2]      : v1 - nums[2]
            let target = ops[2] == "+" ? v2 + nums[3]  : v2 - nums[3]

            guard target >= 1, target <= 60 else { continue }

            let e1 = "(\(nums[0]) \(ops[0]) \(nums[1]))"
            let e2 = "(\(e1) \(ops[1]) \(nums[2]))"
            let solution = "(\(e2) \(ops[2]) \(nums[3]))"

            return (MakeTargetPuzzle(target: target, solutionExpression: solution), nums.shuffled())
        }
        return (MakeTargetPuzzle(target: 10, solutionExpression: "((1 + 2) + 3) + 4"), [1, 2, 3, 4])
    }

    private static func generateMedium() -> (MakeTargetPuzzle, [Int]) {
        let pool = Array((-20...20).filter { $0 != 0 })
        let ops = MakeTargetDifficulty.medium.allowedOperators
        let targetRange = MakeTargetDifficulty.medium.targetRange

        for _ in 0..<500 {
            let nums = Array(pool.shuffled().prefix(4))
            let selectedOps = (0..<3).map { _ in ops.randomElement()! }

            guard let v1 = applyOp(nums[0], selectedOps[0], nums[1]),
                  let v2 = applyOp(v1, selectedOps[1], nums[2]),
                  let target = applyOp(v2, selectedOps[2], nums[3]),
                  targetRange.contains(target)
            else { continue }

            let e1 = "(\(nums[0]) \(selectedOps[0]) \(nums[1]))"
            let e2 = "(\(e1) \(selectedOps[1]) \(nums[2]))"
            let solution = "(\(e2) \(selectedOps[2]) \(nums[3]))"

            return (MakeTargetPuzzle(target: target, solutionExpression: solution), nums.shuffled())
        }
        return (MakeTargetPuzzle(target: 6, solutionExpression: "((2 × 3) + 1) − 1"), [2, 3, 1, 1])
    }

    private static func generateHard() -> (MakeTargetPuzzle, [Int]) {
        let pool = Array((-30...30).filter { $0 != 0 })
        let ops = MakeTargetDifficulty.hard.allowedOperators
        let targetRange = MakeTargetDifficulty.hard.targetRange

        for _ in 0..<1000 {
            let nums = Array(pool.shuffled().prefix(4))
            let selectedOps = (0..<3).map { _ in ops.randomElement()! }

            guard let v1 = applyOp(nums[0], selectedOps[0], nums[1]),
                  let v2 = applyOp(v1, selectedOps[1], nums[2]),
                  let target = applyOp(v2, selectedOps[2], nums[3]),
                  targetRange.contains(target)
            else { continue }

            let e1 = "(\(nums[0]) \(selectedOps[0]) \(nums[1]))"
            let e2 = "(\(e1) \(selectedOps[1]) \(nums[2]))"
            let solution = "(\(e2) \(selectedOps[2]) \(nums[3]))"

            return (MakeTargetPuzzle(target: target, solutionExpression: solution), nums.shuffled())
        }
        return (MakeTargetPuzzle(target: 4, solutionExpression: "((6 ÷ 2) + 1) × 2"), [6, 2, 1, 2])
    }
}

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
        MakeTargetView(onBack: {})
    }
}
