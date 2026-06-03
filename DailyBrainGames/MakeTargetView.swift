//
//  MakeTargetView.swift
//  DailyBrainGames
//
//  Created by Esma Zuurbier on 31/05/2026.
//

import SwiftUI

/// Interactive Make Target game screen.
///
/// The player combines pairs of number cards with arithmetic operators until
/// one card remains. The puzzle is solved when that final card equals the target.
struct MakeTargetView: View {
    /// Called by the custom back button to return to Home.
    let onBack: () -> Void

    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple
    /// Persisted Make Target difficulty.
    @AppStorage("makeTargetDifficulty") private var difficulty: MakeTargetDifficulty = .easy
    /// Current puzzle metadata, including the target and one known solution.
    @State private var puzzle: MakeTargetPuzzle? = nil
    /// Cards currently available to combine.
    @State private var cards: [MakeTargetCard] = []
    /// IDs of the selected cards. At most two cards can be selected.
    @State private var selectedCardIDs: [UUID] = []
    /// Selected arithmetic operator for the next combination.
    @State private var selectedOperator: String? = nil
    /// Previous card layouts used by Undo.
    @State private var cardHistory: [[MakeTargetCard]] = []
    /// Current interaction state for the puzzle.
    @State private var gamePhase: GamePhase = .playing
    /// Whether the help overlay is visible.
    @State private var showingHelp: Bool = false
    /// Timer selection is session-local for this game screen.
    @State private var selectedTimerMode: TimerMode = .untimed
    /// Countdown value in seconds for timed modes.
    @State private var timeRemaining: Int = 0
    /// Whether the countdown is actively running.
    @State private var timerActive: Bool = false
    /// Whether a timed round has ended and the summary view should be shown.
    @State private var timerEnded: Bool = false
    @State private var gameTimer: Timer? = nil
    /// Solved puzzles in the current session.
    @State private var score: Int = 0
    /// Consecutive solved puzzles in the current session.
    @State private var streak: Int = 0
    /// Total puzzles completed (solved or solution revealed).
    @State private var totalAttempted: Int = 0
    /// Puzzles solved without ever triggering the "Incorrect!" banner.
    @State private var firstTryCorrect: Int = 0
    /// Whether the "Incorrect!" state was triggered at least once on the current puzzle.
    @State private var hadIncorrect: Bool = false
    /// Score captured at the moment a timed round ends.
    @State private var finalScore: Int = 0
    /// Accuracy captured at the moment a timed round ends.
    @State private var finalAccuracy: Double = 0

    /// High-level puzzle state used by the Enter button and status label.
    private enum GamePhase { case playing, solved, showingSolution }

    /// Prevents interactions before a timed round starts or while it is paused.
    private var inputBlocked: Bool { selectedTimerMode != .untimed && !timerActive }

    /// Percentage of puzzles solved without ever seeing the "Incorrect!" banner.
    private var accuracy: Double {
        guard totalAttempted > 0 else { return 0 }
        return Double(firstTryCorrect) / Double(totalAttempted) * 100
    }

    /// Whether the current selection would divide by zero.
    private var isDivisionByZero: Bool {
        guard selectedOperator == "÷",
              selectedCardIDs.count == 2,
              let id2 = selectedCardIDs.last,
              let card2 = cards.first(where: { $0.id == id2 })
        else { return false }
        return card2.value == 0
    }

    /// Whether the Enter button should accept the current state.
    ///
    /// While playing, two cards and one valid operator are required. After a
    /// puzzle is solved or the solution is shown, Enter advances to a new puzzle.
    private var canSubmit: Bool {
        guard !inputBlocked else { return false }
        switch gamePhase {
        case .playing: return selectedCardIDs.count == 2 && selectedOperator != nil && !isDivisionByZero
        case .solved, .showingSolution: return true
        }
    }

    /// Whether the current final card is wrong and should show an error message.
    private var showIncorrect: Bool {
        gamePhase == .playing && cards.count == 1 && cards.first?.value != puzzle?.target
    }

    /// Preview of the next card expression produced by the current selection.
    ///
    /// This gives immediate feedback while the player chooses cards/operators
    /// and also warns about division by zero before submission.
    private var expressionPreview: String {
        let c1: MakeTargetCard? = selectedCardIDs.count > 0
            ? cards.first(where: { $0.id == selectedCardIDs[0] }) : nil
        let c2: MakeTargetCard? = selectedCardIDs.count > 1
            ? cards.first(where: { $0.id == selectedCardIDs[1] }) : nil

        if let a = c1, let op = selectedOperator, let b = c2 {
            if op == "÷" && b.value == 0 {
                return "\(a.expression) ÷ 0  ✗"
            }
            if difficulty.showsValues {
                return "(\(a.expression) \(op) \(b.expression)) = \(compute(a.value, op, b.value))"
            } else {
                return "(\(a.expression) \(op) \(b.expression))"
            }
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

            HStack(spacing: 8) {
                pickerMenu(title: difficulty.rawValue, options: MakeTargetDifficulty.allCases) { diff in
                    difficulty = diff
                    score = 0; streak = 0; totalAttempted = 0; firstTryCorrect = 0
                    generateNewPuzzle()
                }
                pickerMenu(title: selectedTimerMode.rawValue, options: TimerMode.allCases) { mode in
                    selectedTimerMode = mode
                    pauseTimer()
                    timerEnded = false
                    if let secs = mode.seconds { timeRemaining = secs }
                    score = 0; streak = 0; totalAttempted = 0; firstTryCorrect = 0
                }
            }
            .padding(.bottom, 8)

            HStack(spacing: 0) {
                statView(label: "Solved",    value: "\(score)")
                statDivider
                statView(label: "Streak",   value: "\(streak)")
                statDivider
                statView(label: "Total",    value: "\(totalAttempted)")
                statDivider
                statView(label: "Accuracy", value: String(format: "%.0f%%", accuracy))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            HStack {
                if selectedTimerMode != .untimed && !timerEnded {
                    Image(systemName: "clock")
                        .foregroundColor(timeRemaining <= 10 ? Color(red: 1, green: 0.4, blue: 0.4) : .white.opacity(0.8))
                    Text(timeString(timeRemaining))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(timeRemaining <= 10 ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                        .frame(minWidth: 48, alignment: .leading)
                }
                Spacer()
                if selectedTimerMode != .untimed && !timerEnded {
                    Button(timerActive ? "Pause" : "Start") { toggleTimer() }
                        .buttonStyle(GlassSmallButtonStyle())
                }
                Button("Reset") { resetPuzzle() }
                    .buttonStyle(GlassSmallButtonStyle())
                    .disabled(timerEnded)
                    .opacity(timerEnded ? 0.35 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.20))
            .frame(width: 1, height: 28)
    }

    func statView(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
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

            if timerEnded {
                VStack(spacing: 12) {
                    Text("Time's up!")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Solved: \(finalScore)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    Text(String(format: "Accuracy: %.0f%%", finalAccuracy))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Button("Close") { playAgain() }
                        .buttonStyle(GlassPlayAgainButtonStyle())
                        .padding(.top, 8)
                }
            } else {
                VStack(spacing: 4) {
                    Text("Target")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                    Text(puzzle != nil ? "\(puzzle!.target)" : " ")
                        .font(.system(size: 69, weight: .bold, design: .rounded))
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
                    .font(.system(size: 30, weight: .medium, design: .monospaced))
                    .foregroundColor(isDivisionByZero ? Color(red: 1.0, green: 0.35, blue: 0.35) : .white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .padding(.horizontal, 20)

                Spacer(minLength: 8)

                statusView
                    .frame(minHeight: 28)

                Spacer(minLength: 0)
                    .frame(maxHeight: 20)
            }

            Spacer()
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
                    .disabled(cardHistory.isEmpty || gamePhase != .playing || inputBlocked)
                    .opacity(cardHistory.isEmpty || gamePhase != .playing || inputBlocked ? 0.35 : 1)

                Spacer()

                bottomButton("Show Solution") { showSolution() }
                    .disabled(gamePhase != .playing || inputBlocked)
                    .opacity(gamePhase != .playing || inputBlocked ? 0.35 : 1)
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
            Text(difficulty.showsValues ? "\(card.value)" : card.expression)
                .font(.system(
                    size: difficulty.showsValues ? 32 : 26,
                    weight: .bold,
                    design: difficulty.showsValues ? .rounded : .monospaced
                ))
                .minimumScaleFactor(difficulty.showsValues ? 0.8 : 0.35)
                .lineLimit(1)
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                .frame(height: 88)
        }
        .glassEffect(isSelected ? .regular.interactive(true) : .regular, in: shape)
        .overlay {
            if isSelected {
                shape.strokeBorder(selectedTheme.accent, lineWidth: 2.5)
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .opacity(gamePhase == .playing && !inputBlocked ? 1 : 0.35)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        .disabled(gamePhase != .playing || inputBlocked)
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
        .opacity(gamePhase == .playing && !inputBlocked ? 1 : 0.35)
        .disabled(gamePhase != .playing || inputBlocked)
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

    /// Selects or deselects a card for the next operation.
    ///
    /// Selection order matters for subtraction and division, so the IDs are kept
    /// in the order the player tapped them.
    private func toggleCard(_ card: MakeTargetCard) {
        if let idx = selectedCardIDs.firstIndex(of: card.id) {
            selectedCardIDs.remove(at: idx)
        } else if selectedCardIDs.count < 2 {
            selectedCardIDs.append(card.id)
        }
    }

    /// Handles the main Enter button.
    ///
    /// During play it combines the selected cards. After a solved/revealed
    /// puzzle, it advances to the next generated puzzle.
    private func pressEnter() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch gamePhase {
        case .playing: submitCombination()
        case .solved, .showingSolution: generateNewPuzzle()
        }
    }

    /// Combines the two selected cards into one new card.
    ///
    /// The previous card list is saved for Undo, the new card is inserted near
    /// the original card positions, and solving the target updates score/streak.
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
            score += 1; streak += 1; totalAttempted += 1
            if !hadIncorrect { firstTryCorrect += 1 }
            withAnimation(.easeInOut(duration: 0.2)) { gamePhase = .solved }
        } else if updated.count == 1 {
            // One card remains but it doesn't match the target — "Incorrect!" will show
            hadIncorrect = true
        }
    }

    /// Restores the previous card layout from `cardHistory`.
    private func undoAction() {
        guard !cardHistory.isEmpty, gamePhase == .playing else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            cards = cardHistory.removeLast()
        }
        selectedCardIDs = []
        selectedOperator = nil
    }

    /// Resets the current puzzle and timer state, then generates a new puzzle.
    private func resetPuzzle() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pauseTimer()
        timerEnded = false
        if let secs = selectedTimerMode.seconds { timeRemaining = secs }
        generateNewPuzzle()
    }

    /// Reveals the stored solution expression and counts the puzzle as attempted.
    private func showSolution() {
        guard gamePhase == .playing else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        totalAttempted += 1
        streak = 0
        selectedCardIDs = []
        selectedOperator = nil
        withAnimation(.easeInOut(duration: 0.2)) { gamePhase = .showingSolution }
    }

    /// Starts or pauses the active timed round.
    private func toggleTimer() { timerActive ? pauseTimer() : startTimer() }

    /// Starts the countdown timer for timed modes.
    private func startTimer() {
        timerActive = true
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if self.timeRemaining > 0 { self.timeRemaining -= 1 } else { self.endTimer() }
        }
    }

    /// Pauses the countdown and releases the scheduled timer.
    private func pauseTimer() {
        timerActive = false
        gameTimer?.invalidate()
        gameTimer = nil
    }

    /// Finishes a timed round and captures the summary stats before resetting live counters.
    private func endTimer() {
        finalScore = score
        finalAccuracy = accuracy
        timerActive = false
        timerEnded = true
        gameTimer?.invalidate()
        gameTimer = nil
        score = 0; streak = 0; totalAttempted = 0; firstTryCorrect = 0
    }

    /// Closes the timed summary and starts a fresh puzzle.
    private func playAgain() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        timerEnded = false
        if let secs = selectedTimerMode.seconds { timeRemaining = secs }
        generateNewPuzzle()
    }

    /// Formats seconds as `m:ss` for the timer label.
    private func timeString(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }

    /// Generates a new puzzle and resets all per-puzzle selection/history state.
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
        hadIncorrect = false
    }

    /// Computes the result of combining two card values.
    ///
    /// Division is rounded here for the live UI because invalid division by zero
    /// is already blocked before submission. Puzzle generation uses `applyOp`,
    /// which is stricter and only accepts clean integer division.
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

    /// Generates a Make Target puzzle and its starting cards.
    ///
    /// The returned numbers are the initial card values. The puzzle also stores
    /// one known solution expression so the UI can reveal it when requested.
    ///
    /// - Parameter difficulty: Difficulty preset controlling ranges and operators.
    /// - Returns: A puzzle plus the four starting card values.
    static func generate(difficulty: MakeTargetDifficulty) -> (MakeTargetPuzzle, [Int]) {
        switch difficulty {
        case .easy:          return generateEasy()
        case .medium, .hard: return generateMedium()
        case .expert:        return generateHard()
        }
    }

    /// Applies an operation during puzzle generation.
    ///
    /// Returns `nil` if the operation is invalid: division by zero, division
    /// with a remainder, or an intermediate result outside the supported range.
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

    /// Generates an Easy puzzle using positive cards and addition/subtraction only.
    ///
    /// The generator requires both `+` and `−` to appear so Easy puzzles still
    /// ask the player to think about operation choice.
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

    /// Generates a Medium/Hard puzzle.
    ///
    /// Medium and Hard use the same numeric generation rules. The difference is
    /// display difficulty: Hard hides intermediate card values.
    private static func generateMedium() -> (MakeTargetPuzzle, [Int]) {
        let pool = Array((-20...20).filter { $0 != 0 })
        let targetRange = MakeTargetDifficulty.medium.targetRange

        for _ in 0..<500 {
            let nums = Array(pool.shuffled().prefix(4))
            // Reject hands with a cancel pair (n and -n both present)
            guard !nums.contains(where: { nums.contains(-$0) }) else { continue }

            // × 40%, + 30%, − 30%
            let selectedOps = (0..<3).map { _ -> String in
                let r = Double.random(in: 0..<1)
                return r < 0.4 ? "×" : (r < 0.7 ? "+" : "−")
            }

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

    /// Generates an Expert puzzle.
    ///
    /// Expert expands the number range, includes division, and requires at least
    /// one multiplication or division operation in the stored solution.
    private static func generateHard() -> (MakeTargetPuzzle, [Int]) {
        let pool = Array((-30...30).filter { $0 != 0 })
        let ops = MakeTargetDifficulty.expert.allowedOperators
        let targetRange = MakeTargetDifficulty.expert.targetRange

        for _ in 0..<1000 {
            let nums = Array(pool.shuffled().prefix(4))
            // Reject hands with a cancel pair (n and -n both present)
            guard !nums.contains(where: { nums.contains(-$0) }) else { continue }

            // Require at least one × or ÷ (applyOp will still reject unclean divisions)
            var selectedOps: [String]
            repeat {
                selectedOps = (0..<3).map { _ in ops.randomElement()! }
            } while !selectedOps.contains("×") && !selectedOps.contains("÷")

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
