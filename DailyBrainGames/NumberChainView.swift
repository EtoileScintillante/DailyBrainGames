//
//  NumberChainView.swift
//  DailyBrainGames
//
//  Created by Esma Zuurbier on 02/06/2026.
//

import SwiftUI
import Foundation

// MARK: - Types

/// Difficulty presets for Number Chain.
///
/// Difficulty changes the number of operations, available operation types,
/// possible step values, and accepted final-answer range.
enum NCDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy", medium = "Medium", hard = "Hard"
    var id: String { rawValue }
}

/// A mathematical operation used in one Number Chain step.
enum ChainOp: String, CaseIterable, Identifiable {
    case add = "+", sub = "−", mul = "×", div = "÷"
    var id: String { rawValue }
}

/// One operation/value pair in a Number Chain puzzle.
///
/// For example, `op == .mul` and `value == 3` represents `×3`.
struct ChainStep {
    let op: ChainOp
    let value: Decimal

    /// User-facing representation of the step, such as `+4` or `÷2`.
    var display: String { op.rawValue + ncFormat(value) }
}

/// A generated Number Chain puzzle.
///
/// In normal mode, the player sees the start value and all steps, then solves
/// for `finalValue`. In missing-step mode, one entry in `steps` is hidden and
/// `missingIndex` points to the hidden operation/value pair.
struct NumberChainPuzzle {
    let start: Decimal
    let steps: [ChainStep]
    let missingIndex: Int?
    let finalValue: Decimal

    /// Whether this puzzle asks for a hidden step instead of the final answer.
    var isMissingStep: Bool { missingIndex != nil }
}

// MARK: - Helpers

/// Formats a decimal for puzzle display.
///
/// Values are rounded to two decimal places, trimmed with `%g`, and displayed
/// with a comma decimal separator to match the keypad input.
private func ncFormat(_ v: Decimal) -> String {
    let d = NSDecimalNumber(decimal: v).doubleValue
    let r = (d * 100).rounded() / 100
    let s = String(format: "%.10g", r)
    return s.replacingOccurrences(of: ".", with: ",")
}

/// Checks whether a decimal can be represented cleanly with at most two digits after the decimal separator.
///
/// The generator uses this to avoid division chains that produce long repeating
/// decimals, which would be frustrating to solve on the keypad.
private func isClean2DP(_ d: Decimal) -> Bool {
    let scaled = d * 100
    let intPart = NSDecimalNumber(decimal: scaled).intValue
    return Decimal(intPart) == scaled
}

// MARK: - Generation

/// Tunable puzzle generation parameters for a difficulty level.
private struct NCParams {
    /// Number of operations in the chain.
    let stepCount: Int
    /// Inclusive range for the starting value.
    let startRange: ClosedRange<Int>
    /// Operations that may appear in the generated chain.
    let opsPool: [ChainOp]
    /// Candidate values for addition and subtraction steps.
    let addSubValues: [Decimal]
    /// Candidate values for multiplication steps.
    let mulValues: [Decimal]
    /// Candidate values for division steps.
    let divValues: [Decimal]
    /// Allowed final-answer range after all steps have been applied.
    let finalRangeDouble: ClosedRange<Double>
}

/// Returns the generation rules for one difficulty preset.
private func ncParams(_ d: NCDifficulty) -> NCParams {
    switch d {
    case .easy:
        return NCParams(
            stepCount: 3,
            startRange: 1...20,
            opsPool: [.add, .sub, .mul],
            addSubValues: (1...15).map { Decimal($0) },
            mulValues: [2, 3],
            divValues: [],
            finalRangeDouble: -100...100
        )
    case .medium:
        return NCParams(
            stepCount: 4,
            startRange: 1...30,
            opsPool: [.add, .sub, .mul, .div],
            addSubValues: (1...25).map { Decimal($0) },
            mulValues: [2, 3, 4, 5],
            divValues: [2, 3, 4, 5],
            finalRangeDouble: -200...200
        )
    case .hard:
        let asPool: [Decimal] = (1...15).map { Decimal($0) } + [
            Decimal(string: "0.5")!, Decimal(string: "1.5")!,
            Decimal(string: "2.5")!, Decimal(string: "3.5")!,
            Decimal(string: "4.5")!, Decimal(string: "5.5")!
        ]
        return NCParams(
            stepCount: 5,
            startRange: 1...50,
            opsPool: [.add, .sub, .mul, .div],
            addSubValues: asPool,
            mulValues: [Decimal(string: "0.5")!, Decimal(string: "1.5")!, 2,
                        Decimal(string: "2.5")!, 3, 4],
            divValues: [2, 4, 5, 10],
            finalRangeDouble: -500...500
        )
    }
}

/// Generates a playable Number Chain puzzle.
///
/// The generator repeatedly samples a start value and operation chain until it
/// finds one that satisfies the difficulty constraints: valid divisions, clean
/// two-decimal intermediate values, a reasonable final range, and distinct step
/// values. If no valid random puzzle is found, it returns a simple fallback.
///
/// - Parameters:
///   - difficulty: Difficulty preset controlling operation count and value ranges.
///   - missingStep: Whether one operation should be hidden from the player.
/// - Returns: A puzzle ready to display.
private func generateNCPuzzle(difficulty: NCDifficulty, missingStep: Bool) -> NumberChainPuzzle {
    let p = ncParams(difficulty)
    for _ in 0..<1000 {
        let startInt = Int.random(in: p.startRange)
        var current = Decimal(startInt)

        var ops: [ChainOp]
        var opAttempt = 0
        repeat {
            ops = (0..<p.stepCount).map { _ in p.opsPool.randomElement()! }
            opAttempt += 1
        } while Set(ops).count < 2 && opAttempt < 50

        var steps: [ChainStep] = []
        var valid = true

        for op in ops {
            switch op {
            case .add:
                let v = p.addSubValues.randomElement()!
                current += v
                steps.append(ChainStep(op: .add, value: v))
            case .sub:
                let v = p.addSubValues.randomElement()!
                current -= v
                steps.append(ChainStep(op: .sub, value: v))
            case .mul:
                let v = p.mulValues.randomElement()!
                current *= v
                steps.append(ChainStep(op: .mul, value: v))
            case .div:
                let validDivs = p.divValues.filter { d in
                    guard d != 0 else { return false }
                    return isClean2DP(current / d)
                }
                guard let v = validDivs.randomElement() else { valid = false; break }
                current /= v
                steps.append(ChainStep(op: .div, value: v))
            }
            guard valid else { break }
            guard isClean2DP(current) else { valid = false; break }
            let absDouble = abs(NSDecimalNumber(decimal: current).doubleValue)
            guard absDouble < 5000 else { valid = false; break }
        }

        guard valid, steps.count == p.stepCount else { continue }

        let finalDouble = NSDecimalNumber(decimal: current).doubleValue
        guard p.finalRangeDouble.contains(finalDouble) else { continue }

        if difficulty != .hard {
            let intVal = NSDecimalNumber(decimal: current).intValue
            guard Decimal(intVal) == current else { continue }
        }

        // All step values must be distinct (avoids e.g. ÷5 ×5 ÷5 ×5)
        guard Set(steps.map(\.value)).count == steps.count else { continue }

        let missingIndex: Int? = missingStep ? Int.random(in: 0..<p.stepCount) : nil
        return NumberChainPuzzle(start: Decimal(startInt), steps: steps, missingIndex: missingIndex, finalValue: current)
    }
    // Fallback: 5 + 3 = 8, × 2 = 16, − 4 = 12
    let fallbackSteps = [
        ChainStep(op: .add, value: 3),
        ChainStep(op: .mul, value: 2),
        ChainStep(op: .sub, value: 4)
    ]
    return NumberChainPuzzle(
        start: 5,
        steps: fallbackSteps,
        missingIndex: missingStep ? 1 : nil,
        finalValue: 12
    )
}

// MARK: - View

/// Interactive Number Chain game screen.
///
/// The player either solves the final value of an operation chain or, in
/// missing-step mode, identifies the hidden operation/value pair.
struct NumberChainView: View {
    /// Called by the custom back button to return to Home.
    let onBack: () -> Void

    /// Persisted puzzle difficulty.
    @AppStorage("ncDifficulty") private var difficulty: NCDifficulty = .easy
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple
    /// Persisted mode flag that switches between final-answer and missing-step puzzles.
    @AppStorage("ncMissingStep") private var missingStepMode: Bool = false
    /// Timer selection is intentionally session-local for this game screen.
    @State private var selectedTimerMode: TimerMode = .untimed

    /// Current puzzle being displayed.
    @State private var puzzle: NumberChainPuzzle? = nil
    /// Digits typed on the custom keypad, using a comma as the decimal separator.
    @State private var inputDigits: String = ""
    /// Whether the currently typed numeric value should be treated as negative.
    @State private var isNegativeValue: Bool = false
    /// Operation selected by the player in missing-step mode.
    @State private var selectedOp: ChainOp? = nil

    /// Short response shown after submit, such as "Correct" or "Try again".
    @State private var feedback: String = ""
    @State private var feedbackColor: Color = .white
    /// Number of wrong tries on the current puzzle. The second wrong try reveals the answer.
    @State private var wrongAttempts: Int = 0
    /// True while the correct answer is being shown after repeated wrong attempts.
    @State private var showingAnswer: Bool = false

    /// Correct answers in the current session.
    @State private var score: Int = 0
    /// Consecutive correct answers in the current session.
    @State private var streak: Int = 0
    /// Submitted puzzles counted for accuracy.
    @State private var totalAttempted: Int = 0

    /// Countdown value in seconds for timed modes.
    @State private var timeRemaining: Int = 0
    /// Whether the countdown is actively running.
    @State private var timerActive: Bool = false
    /// Whether a timed round has ended and the summary view should be shown.
    @State private var timerEnded: Bool = false
    @State private var gameTimer: Timer? = nil
    /// Score captured at the moment a timed round ends.
    @State private var finalScore: Int = 0
    /// Accuracy captured at the moment a timed round ends.
    @State private var finalAccuracy: Double = 0

    /// Percentage of submitted puzzles answered correctly.
    var accuracy: Double {
        guard totalAttempted > 0 else { return 0 }
        return Double(score) / Double(totalAttempted) * 100
    }

    /// Prevents keypad input before a timed round starts or while it is paused.
    var inputBlocked: Bool { selectedTimerMode != .untimed && !timerActive }

    /// The answer text shown in the input capsule.
    ///
    /// Normal mode displays only the typed number. Missing-step mode combines
    /// the selected operation and typed number, using `?` placeholders until
    /// each piece has been provided.
    var answerDisplay: String {
        guard let p = puzzle, p.isMissingStep else {
            // Normal mode: "?" until digits are entered; sign is invisible until then
            if inputDigits.isEmpty { return "?" }
            return (isNegativeValue ? "−" : "") + inputDigits
        }
        // Missing step mode
        if selectedOp == nil && inputDigits.isEmpty { return "?" }
        let opStr = selectedOp?.rawValue ?? "?"
        let numPart = inputDigits.isEmpty ? "?" : (isNegativeValue ? "−" : "") + inputDigits
        return opStr + numPart
    }

    var body: some View {
        VStack(spacing: 0) {
            headerArea
            questionArea
            keypadArea
        }
        .safeAreaPadding([.top, .bottom])
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { setupGame() }
        }
    }

    // MARK: - Header

    var headerArea: some View {
        VStack(spacing: 12) {
            ZStack {
                Text("Number Chain")
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

            HStack(spacing: 8) {
                pickerMenu(title: difficulty.rawValue, options: NCDifficulty.allCases) { d in
                    difficulty = d; resetGame()
                }
                pickerMenu(title: selectedTimerMode.rawValue, options: TimerMode.allCases) { mode in
                    selectedTimerMode = mode; resetGame()
                }
            }
            .padding(.horizontal, 16)

            HStack(spacing: 0) {
                statView(label: "Score",    value: "\(score)")
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

            HStack {
                Button(action: {
                    missingStepMode.toggle()
                    loadNextPuzzle()
                }) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(missingStepMode ? selectedTheme.accent : Color.white.opacity(0.35))
                            .frame(width: 8, height: 8)
                        Text("Missing Step")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: Capsule())
                    .overlay {
                        if missingStepMode {
                            Capsule().strokeBorder(selectedTheme.accent, lineWidth: 2)
                        }
                    }
                }

                if selectedTimerMode != .untimed {
                    if timerEnded {
                        Text("Time's up!")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 1, green: 0.4, blue: 0.4))
                    } else {
                        Image(systemName: "clock")
                            .foregroundColor(timeRemaining <= 10 ? Color(red: 1, green: 0.4, blue: 0.4) : .white.opacity(0.8))
                        Text(timeString(timeRemaining))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(timeRemaining <= 10 ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                            .frame(minWidth: 48, alignment: .leading)
                    }
                    Spacer()
                    if !timerEnded {
                        Button(timerActive ? "Pause" : "Start") { toggleTimer() }
                            .buttonStyle(GlassSmallButtonStyle())
                    }
                } else {
                    Spacer()
                }
                Button("Reset") { resetGame() }
                    .buttonStyle(GlassSmallButtonStyle())
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

    // MARK: - Question Area

    var questionArea: some View {
        VStack(spacing: 10) {
            Spacer()
            if timerEnded {
                VStack(spacing: 12) {
                    Text("Time's up!")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Score: \(finalScore)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    Text(String(format: "Accuracy: %.0f%%", finalAccuracy))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Button("Close") { resetGame() }
                        .buttonStyle(GlassPlayAgainButtonStyle())
                        .padding(.top, 8)
                }
            } else if let p = puzzle {
                VStack(spacing: 14) {
                    // Line 1
                    if p.isMissingStep {
                        HStack(spacing: 10) {
                            Text("Start: \(ncFormat(p.start))")
                            Text("⇒")
                                .foregroundColor(.white.opacity(0.5))
                            Text("End: \(ncFormat(p.finalValue))")
                        }
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    } else {
                        Text("Start: \(ncFormat(p.start))")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    // Line 2: steps
                    stepsLine(p)

                    // Line 3 label
                    Text(p.isMissingStep ? "Missing step:" : "Answer:")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    // Answer input
                    Text(answerDisplay)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(
                            inputDigits.isEmpty && selectedOp == nil
                            ? Color.white.opacity(0.25) : .white
                        )
                        .frame(minWidth: 100)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 14))

                    // Feedback
                    Text(feedback)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(feedbackColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .animation(.easeInOut(duration: 0.2), value: feedback)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    func stepsLine(_ p: NumberChainPuzzle) -> some View {
        let parts: [String] = p.steps.indices.map { i in
            p.missingIndex == i ? "?" : p.steps[i].display
        }
        return Text(parts.joined(separator: " → "))
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .minimumScaleFactor(0.45)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
    }

    // MARK: - Keypad

    var keypadArea: some View {
        VStack(spacing: 10) {
            // Operator row shown only in missing step mode
            if puzzle?.isMissingStep == true {
                HStack(spacing: 10) {
                    ForEach(ChainOp.allCases) { op in
                        operatorKey(op)
                    }
                }
            }

            ForEach([[7, 8, 9], [4, 5, 6], [1, 2, 3]], id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        ncKeyButton(label: "\(digit)", disabled: inputBlocked || showingAnswer) {
                            appendDigit("\(digit)")
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                let signLabel = puzzle?.isMissingStep == true ? "±" : "−"
                ncKeyButton(label: signLabel, isSignButton: true, disabled: inputBlocked || showingAnswer) {
                    toggleSign()
                }
                ncKeyButton(label: ",", disabled: inputBlocked || showingAnswer) {
                    appendDecimal()
                }
                ncKeyButton(label: "0", disabled: inputBlocked || showingAnswer) {
                    appendDigit("0")
                }
                ncKeyButton(label: "⌫", disabled: inputBlocked || showingAnswer) {
                    backspace()
                }
                ncKeyButton(label: "→", isEnter: true, disabled: inputBlocked || isBlockedByDivZero) {
                    submitAnswer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 28)
    }

    func operatorKey(_ op: ChainOp) -> some View {
        let isSelected = selectedOp == op
        let shape = RoundedRectangle(cornerRadius: 13)
        return Button(action: {
            guard !inputBlocked, !showingAnswer else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedOp = isSelected ? nil : op
        }) {
            Text(op.rawValue)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundColor(inputBlocked || showingAnswer ? Color.white.opacity(0.25) : .white)
        }
        .glassEffect(isSelected ? .regular.interactive(true) : .regular, in: shape)
        .overlay {
            if isSelected {
                shape.strokeBorder(selectedTheme.accent, lineWidth: 2)
            }
        }
        .disabled(inputBlocked || showingAnswer)
    }

    func ncKeyButton(
        label: String,
        isEnter: Bool = false,
        isSignButton: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 13)
        let signActive = isSignButton && isNegativeValue
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(label)
                .font(.system(size: isEnter ? 24 : 22, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .foregroundColor(disabled ? Color.white.opacity(0.25) : .white)
        }
        .glassEffect(isEnter ? .regular.interactive(true) : .regular, in: shape)
        .overlay {
            if signActive {
                shape.strokeBorder(selectedTheme.accent, lineWidth: 2)
            }
        }
        .disabled(disabled)
    }

    // MARK: - Input Actions

    /// Appends a keypad digit to the current input if input is allowed.
    func appendDigit(_ d: String) {
        guard !inputBlocked, !showingAnswer, inputDigits.count < 7 else { return }
        inputDigits += d
    }

    /// Removes the last typed digit or decimal separator.
    func backspace() {
        guard !inputBlocked, !showingAnswer, !inputDigits.isEmpty else { return }
        inputDigits.removeLast()
    }

    /// Toggles the sign for the currently typed value.
    func toggleSign() {
        guard !inputBlocked, !showingAnswer else { return }
        isNegativeValue.toggle()
    }

    /// Appends a comma decimal separator, inserting a leading zero when needed.
    func appendDecimal() {
        guard !inputBlocked, !showingAnswer, !inputDigits.contains(",") else { return }
        if inputDigits.isEmpty { inputDigits = "0" }
        inputDigits += ","
    }

    // MARK: - Submit

    /// True when the submit button should be disabled due to a ÷0 entry in missing-step mode.
    var isBlockedByDivZero: Bool {
        guard puzzle?.isMissingStep == true, selectedOp == .div, !inputDigits.isEmpty else { return false }
        let raw = inputDigits.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: raw) == 0
    }

    /// Validates the current input against the puzzle.
    ///
    /// Normal puzzles compare the typed number with `finalValue`. Missing-step
    /// puzzles execute the user's submitted step inside the chain and check
    /// whether the final result matches `finalValue`, accepting any mathematically
    /// equivalent step instead of requiring an exact op/value match.
    func submitAnswer() {
        if showingAnswer {
            showingAnswer = false
            feedback = ""
            loadNextPuzzle()
            return
        }

        guard !inputBlocked, let p = puzzle, !inputDigits.isEmpty else { return }

        let rawStr = (isNegativeValue ? "-" : "") + inputDigits.replacingOccurrences(of: ",", with: ".")
        guard let userValue = Decimal(string: rawStr) else { return }

        if p.isMissingStep {
            guard let missingIdx = p.missingIndex, let userOp = selectedOp else { return }

            // Compute the value immediately before the missing step
            var valueBefore = p.start
            for i in 0..<missingIdx {
                guard let next = applyStep(valueBefore, op: p.steps[i].op, stepVal: p.steps[i].value) else { return }
                valueBefore = next
            }

            // Apply the user's submitted step (also guards ÷0)
            guard let intermediate = applyStep(valueBefore, op: userOp, stepVal: userValue) else { return }

            // Run remaining steps after the missing one
            var finalResult = intermediate
            for i in (missingIdx + 1)..<p.steps.count {
                guard let next = applyStep(finalResult, op: p.steps[i].op, stepVal: p.steps[i].value) else { return }
                finalResult = next
            }

            if finalResult == p.finalValue {
                markCorrect()
            } else {
                markWrong(correctAnswer: "Step: \(p.steps[missingIdx].display)")
            }
        } else {
            if userValue == p.finalValue {
                markCorrect()
            } else {
                markWrong(correctAnswer: "Answer: \(ncFormat(p.finalValue))")
            }
        }
    }

    /// Applies one chain operation to a value, returning `nil` on division by zero.
    private func applyStep(_ value: Decimal, op: ChainOp, stepVal: Decimal) -> Decimal? {
        switch op {
        case .add: return value + stepVal
        case .sub: return value - stepVal
        case .mul: return value * stepVal
        case .div:
            guard stepVal != 0 else { return nil }
            return value / stepVal
        }
    }

    /// Records a correct answer, clears input, and advances after a short success pause.
    private func markCorrect() {
        score += 1; streak += 1; totalAttempted += 1
        wrongAttempts = 0
        feedback = "Correct ✓"
        feedbackColor = selectedTheme.accent
        clearInput()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            feedback = ""
            loadNextPuzzle()
        }
    }

    /// Records a wrong answer.
    ///
    /// The first wrong attempt lets the player try again. The second wrong
    /// attempt counts the puzzle, breaks the streak, and reveals the answer.
    private func markWrong(correctAnswer: String) {
        wrongAttempts += 1
        clearInput()
        if wrongAttempts >= 2 {
            totalAttempted += 1
            streak = 0
            wrongAttempts = 0
            feedback = correctAnswer
            feedbackColor = .orange
            showingAnswer = true
        } else {
            feedback = "Try again"
            feedbackColor = Color(red: 1.0, green: 0.35, blue: 0.35)
        }
    }

    /// Clears all user-entered answer state for the current puzzle.
    private func clearInput() {
        inputDigits = ""
        isNegativeValue = false
        selectedOp = nil
    }

    // MARK: - Game Setup

    /// Initializes timer state and loads the first puzzle when the view appears.
    func setupGame() {
        if let secs = selectedTimerMode.seconds { timeRemaining = secs }
        loadNextPuzzle()
    }

    /// Generates and displays the next puzzle, resetting per-puzzle state.
    func loadNextPuzzle() {
        let p = generateNCPuzzle(difficulty: difficulty, missingStep: missingStepMode)
        withAnimation(.easeInOut(duration: 0.2)) { puzzle = p }
        clearInput()
        wrongAttempts = 0
        showingAnswer = false
        feedback = ""
    }

    // MARK: - Timer

    /// Starts or pauses the active timed round.
    func toggleTimer() { timerActive ? pauseTimer() : startTimer() }

    /// Starts the countdown timer for timed modes.
    func startTimer() {
        timerActive = true
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 { timeRemaining -= 1 } else { endTimer() }
        }
    }

    /// Pauses the countdown and releases the scheduled timer.
    func pauseTimer() {
        timerActive = false
        gameTimer?.invalidate()
        gameTimer = nil
    }

    /// Finishes a timed round and captures the summary stats before resetting live counters.
    func endTimer() {
        finalScore = score
        finalAccuracy = accuracy
        timerActive = false; timerEnded = true
        gameTimer?.invalidate(); gameTimer = nil
        score = 0; streak = 0; totalAttempted = 0
    }

    /// Formats seconds as `m:ss` for the timer label.
    func timeString(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }

    // MARK: - Reset

    /// Resets score, timer, feedback, input, and puzzle state for a fresh round.
    func resetGame() {
        pauseTimer()
        score = 0; streak = 0; totalAttempted = 0
        wrongAttempts = 0; showingAnswer = false; timerEnded = false; timerActive = false
        feedback = ""
        if let secs = selectedTimerMode.seconds { timeRemaining = secs }
        clearInput()
        loadNextPuzzle()
    }
}

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
        NumberChainView(onBack: {})
    }
}
