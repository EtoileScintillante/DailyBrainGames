//
//  SequencesView.swift
//  DailyMentalMath
//
//  Created by Esma Zuurbier on 29/05/2026.
//

import SwiftUI

struct SequencesView: View {
    let onBack: () -> Void

    @AppStorage("selectedDifficulty") private var selectedDifficulty: Difficulty = .easy
    @State private var selectedTimerMode: TimerMode = .untimed
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple

    @State private var questionQueue: [SequenceQuestion] = []
    @State private var currentQuestion: SequenceQuestion? = nil

    @State private var inputDigits: String = ""
    @State private var isNegative: Bool = false

    @State private var feedback: String = ""
    @State private var feedbackColor: Color = Color(red: 0.70, green: 0.45, blue: 1.00)
    @State private var wrongAttempts: Int = 0
    @State private var showingAnswer: Bool = false

    @State private var score: Int = 0
    @State private var streak: Int = 0
    @State private var totalAttempted: Int = 0

    @State private var timeRemaining: Int = 0
    @State private var timerActive: Bool = false
    @State private var timerEnded: Bool = false
    @State private var gameTimer: Timer? = nil

    var accuracy: Double {
        guard totalAttempted > 0 else { return 0 }
        return Double(score) / Double(totalAttempted) * 100
    }

    var answerDisplay: String {
        guard !inputDigits.isEmpty else { return "_" }
        return (isNegative ? "-" : "") + inputDigits
    }

    var inputBlocked: Bool { timerEnded }

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
                Text("Sequences")
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
                pickerMenu(title: selectedDifficulty.rawValue, options: Difficulty.allCases) { diff in
                    selectedDifficulty = diff; resetGame()
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
        VStack(spacing: 14) {
            Spacer()
            if timerEnded {
                VStack(spacing: 12) {
                    Text("Time's up!")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Score: \(score)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    Text(String(format: "Accuracy: %.0f%%", accuracy))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Button("Play Again") { resetGame() }
                        .buttonStyle(GlassPlayAgainButtonStyle())
                        .padding(.top, 8)
                }
            } else {
                Text(currentQuestion?.display ?? " ")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .opacity(currentQuestion != nil ? 1 : 0)

                Text(feedback)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(feedbackColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .animation(.easeInOut(duration: 0.2), value: feedback)

                Text(answerDisplay)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(inputDigits.isEmpty ? Color.white.opacity(0.25) : .white)
                    .frame(minWidth: 100)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Keypad

    var keypadArea: some View {
        VStack(spacing: 10) {
            ForEach([[7, 8, 9], [4, 5, 6], [1, 2, 3]], id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        keyButton(label: "\(digit)", disabled: inputBlocked || showingAnswer) {
                            appendDigit("\(digit)")
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                keyButton(label: "−", isMinusButton: true, disabled: inputBlocked || showingAnswer) {
                    pressMinus()
                }
                keyButton(label: ",", disabled: inputBlocked || showingAnswer) {
                    appendComma()
                }
                keyButton(label: "0", disabled: inputBlocked || showingAnswer) {
                    appendDigit("0")
                }
                keyButton(label: "⌫", disabled: inputBlocked || showingAnswer) {
                    backspace()
                }
                keyButton(label: "→", isEnter: true, disabled: inputBlocked) {
                    submitAnswer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 28)
    }

    func keyButton(
        label: String,
        isEnter: Bool = false,
        isMinusButton: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 13)
        let minusActive = isMinusButton && isNegative

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
            if minusActive {
                shape.strokeBorder(selectedTheme.accent, lineWidth: 2)
            }
        }
        .disabled(disabled)
    }

    // MARK: - Input Actions

    func appendDigit(_ d: String) {
        guard !inputBlocked, !showingAnswer, inputDigits.count < 7 else { return }
        inputDigits += d
    }

    func backspace() {
        guard !inputBlocked, !showingAnswer, !inputDigits.isEmpty else { return }
        inputDigits.removeLast()
    }

    func pressMinus() {
        guard !inputBlocked, !showingAnswer else { return }
        isNegative.toggle()
    }

    func appendComma() {
        guard !inputBlocked, !showingAnswer, !inputDigits.contains(",") else { return }
        if inputDigits.isEmpty { inputDigits = "0" }
        inputDigits += ","
    }

    func submitAnswer() {
        if showingAnswer {
            showingAnswer = false
            feedback = ""
            nextQuestion()
            return
        }

        guard !inputBlocked, let q = currentQuestion, !inputDigits.isEmpty else { return }
        let raw = (isNegative ? "-" : "") + inputDigits
        guard let userValue = Int(raw) else { return }

        if userValue == q.answer {
            score += 1; streak += 1; totalAttempted += 1
            wrongAttempts = 0
            feedback = "Correct ✓"; feedbackColor = selectedTheme.accent
            inputDigits = ""; isNegative = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                feedback = ""
                nextQuestion()
            }
        } else {
            wrongAttempts += 1
            inputDigits = ""; isNegative = false
            if wrongAttempts >= 3 {
                totalAttempted += 1; streak = 0; wrongAttempts = 0
                feedback = "Answer: \(q.answer)  ·  Pattern: \(q.patternDescription)"
                feedbackColor = .orange
                showingAnswer = true
            } else {
                feedback = "Try again"
                feedbackColor = Color(red: 1.0, green: 0.35, blue: 0.35)
            }
        }
    }

    // MARK: - Question Generation

    func setupGame() {
        if let secs = selectedTimerMode.seconds { timeRemaining = secs }
        refillQueue()
        nextQuestion()
    }

    func nextQuestion() {
        if questionQueue.count < 5 { refillQueue() }
        currentQuestion = questionQueue.removeFirst()
        inputDigits = ""; isNegative = false; wrongAttempts = 0
    }

    func refillQueue() {
        for _ in 0..<10 { questionQueue.append(generateSequence()) }
    }

    func generateSequence() -> SequenceQuestion {
        Double.random(in: 0...1) < 0.65 ? makeConstantSequence() : makeAlternatingSequence()
    }

    func makeConstantSequence() -> SequenceQuestion {
        let step = nonZeroRandom(in: -12...12)
        // Ensure all 5 terms stay > 0
        let minOffset = min(0, 4 * step)
        let minStart = 1 - minOffset
        let start = Int.random(in: minStart...(minStart + 40))
        let terms = (0..<5).map { start + $0 * step }

        let missingIndex = Bool.random() ? 4 : Int.random(in: 1...3)
        let displayTerms: [Int?] = (0..<5).map { $0 == missingIndex ? nil : terms[$0] }
        let patternStr = step > 0 ? "+\(step)" : "\(step)"

        return SequenceQuestion(terms: displayTerms, answer: terms[missingIndex], patternDescription: patternStr)
    }

    func makeAlternatingSequence() -> SequenceQuestion {
        let s1 = nonZeroRandom(in: -8...8)
        var s2 = nonZeroRandom(in: -8...8)
        while s2 == s1 { s2 = nonZeroRandom(in: -8...8) }

        // Offsets for terms 0–4: 0, s1, s1+s2, 2s1+s2, 2s1+2s2
        let offsets = [0, s1, s1 + s2, 2 * s1 + s2, 2 * s1 + 2 * s2]
        let minOffset = offsets.min()!
        let minStart = max(1, 1 - minOffset)
        let start = Int.random(in: minStart...(minStart + 30))
        let terms = offsets.map { start + $0 }

        // Require at least 2 steps visible so the alternating pattern is deducible
        let missingIndex = [2, 3, 4].randomElement()!
        let displayTerms: [Int?] = (0..<5).map { $0 == missingIndex ? nil : terms[$0] }
        let s1Str = s1 > 0 ? "+\(s1)" : "\(s1)"
        let s2Str = s2 > 0 ? "+\(s2)" : "\(s2)"

        return SequenceQuestion(terms: displayTerms, answer: terms[missingIndex], patternDescription: "\(s1Str), \(s2Str)")
    }

    func nonZeroRandom(in range: ClosedRange<Int>) -> Int {
        var v = Int.random(in: range)
        while v == 0 { v = Int.random(in: range) }
        return v
    }

    // MARK: - Timer

    func toggleTimer() { timerActive ? pauseTimer() : startTimer() }

    func startTimer() {
        timerActive = true
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 { timeRemaining -= 1 } else { endTimer() }
        }
    }

    func pauseTimer() {
        timerActive = false
        gameTimer?.invalidate()
        gameTimer = nil
    }

    func endTimer() {
        timerActive = false; timerEnded = true
        gameTimer?.invalidate(); gameTimer = nil
    }

    func timeString(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }

    // MARK: - Reset

    func resetGame() {
        pauseTimer()
        score = 0; streak = 0; totalAttempted = 0
        feedback = ""; inputDigits = ""; isNegative = false
        wrongAttempts = 0; showingAnswer = false; timerEnded = false; timerActive = false
        if let secs = selectedTimerMode.seconds { timeRemaining = secs }
        questionQueue = []
        refillQueue()
        nextQuestion()
    }
}

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
        SequencesView(onBack: {})
    }
}
