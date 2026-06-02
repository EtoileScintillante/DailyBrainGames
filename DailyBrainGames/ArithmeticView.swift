//
//  ArithmeticView.swift
//  DailyBrainGames
//
//  Created by Esma Zuurbier on 29/05/2026.
//

import SwiftUI

struct ArithmeticView: View {
    let onBack: () -> Void

    @AppStorage("selectedOperation") private var selectedOperation: Operation = .addition
    @AppStorage("selectedDifficulty") private var selectedDifficulty: Difficulty = .easy
    @State private var selectedTimerMode: TimerMode = .untimed
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple
    @AppStorage("decimalsEnabled") private var decimalsEnabled: Bool = false

    @State private var questionQueue: [Question] = []
    @State private var currentQuestion: Question? = nil

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
    @State private var finalScore: Int = 0
    @State private var finalAccuracy: Double = 0

    var accuracy: Double {
        guard totalAttempted > 0 else { return 0 }
        return Double(score) / Double(totalAttempted) * 100
    }

    var answerDisplay: String {
        guard !inputDigits.isEmpty else { return "_" }
        return (isNegative ? "-" : "") + inputDigits
    }

    var inputBlocked: Bool { selectedTimerMode != .untimed && !timerActive }

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
                Text("Arithmetic")
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
                pickerMenu(title: selectedOperation.rawValue, options: Operation.allCases) { op in
                    selectedOperation = op; resetGame()
                }
                pickerMenu(title: selectedDifficulty.rawValue, options: Difficulty.allCases) { diff in
                    selectedDifficulty = diff
                    if diff == .expert { decimalsEnabled = false }
                    resetGame()
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
                if selectedDifficulty == .easy || selectedDifficulty == .medium || selectedDifficulty == .hard {
                    Button(action: {
                        decimalsEnabled.toggle()
                        questionQueue = []
                    }) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(decimalsEnabled ? selectedTheme.accent : Color.white.opacity(0.35))
                                .frame(width: 8, height: 8)
                            Text("Decimals")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .glassEffect(.regular, in: Capsule())
                        .overlay {
                            if decimalsEnabled {
                                Capsule().strokeBorder(selectedTheme.accent, lineWidth: 2)
                            }
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
        VStack(spacing: 14) {
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
            } else {
                Text(currentQuestion?.display ?? " ")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
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
        let raw = (isNegative ? "-" : "") + inputDigits.replacingOccurrences(of: ",", with: ".")
        guard let userValue = Double(raw) else { return }

        if abs(userValue - q.answer) < 0.001 {
            score += 1
            streak += 1
            totalAttempted += 1
            wrongAttempts = 0
            feedback = "Correct ✓"
            feedbackColor = selectedTheme.accent
            inputDigits = ""
            isNegative = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                feedback = ""
                nextQuestion()
            }
        } else {
            wrongAttempts += 1
            inputDigits = ""
            isNegative = false
            if wrongAttempts >= 2 {
                totalAttempted += 1
                streak = 0
                wrongAttempts = 0
                feedback = "Answer: \(formatNum(q.answer))"
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
        inputDigits = ""
        isNegative = false
        wrongAttempts = 0
    }

    func refillQueue() {
        for _ in 0..<10 { questionQueue.append(generateQuestion()) }
    }

    func generateQuestion() -> Question {
        let op: Operation
        if selectedOperation == .mixed {
            op = [Operation.addition, .subtraction, .multiplication, .division].randomElement()!
        } else {
            op = selectedOperation
        }
        if decimalsEnabled && selectedDifficulty != .expert && Bool.random() {
            return makeDecimalQuestion(op: op)
        }
        return makeQuestion(op: op)
    }

    func makeQuestion(op: Operation) -> Question {
        switch op {
        case .addition:
            let (a, b) = addSubRange()
            return Question(lhs: a, rhs: b, op: .addition, answer: a + b)
        case .subtraction:
            let (a, b) = addSubRange()
            return Question(lhs: a, rhs: b, op: .subtraction, answer: a - b)
        case .multiplication:
            let (a, b) = mulRange()
            return Question(lhs: a, rhs: b, op: .multiplication, answer: a * b)
        case .division:
            return makeDivision()
        case .mixed:
            return makeQuestion(op: [Operation.addition, .subtraction, .multiplication, .division].randomElement()!)
        }
    }

    func addSubRange() -> (Int, Int) {
        switch selectedDifficulty {
        case .easy:   return (Int.random(in: 1...20),      Int.random(in: 1...20))
        case .medium: return (Int.random(in: 10...100),    Int.random(in: 10...100))
        case .hard:   return (Int.random(in: 100...1000),  Int.random(in: 100...1000))
        case .expert: return (Int.random(in: 1000...9999), Int.random(in: 1000...9999))
        }
    }

    func mulRange() -> (Int, Int) {
        switch selectedDifficulty {
        case .easy:   return (Int.random(in: 2...10),    Int.random(in: 2...10))
        case .medium: return (Int.random(in: 10...99),   Int.random(in: 2...9))
        case .hard:   return (Int.random(in: 10...99),   Int.random(in: 10...99))
        case .expert: return (Int.random(in: 100...999), Int.random(in: 10...99))
        }
    }

    func makeDivision() -> Question {
        switch selectedDifficulty {
        case .easy:
            let answer = Int.random(in: 2...10);   let divisor = Int.random(in: 2...10)
            return Question(lhs: answer * divisor, rhs: divisor, op: .division, answer: answer)
        case .medium:
            let answer = Int.random(in: 2...50);   let divisor = Int.random(in: 2...12)
            return Question(lhs: answer * divisor, rhs: divisor, op: .division, answer: answer)
        case .hard:
            let answer = Int.random(in: 10...100); let divisor = Int.random(in: 2...20)
            return Question(lhs: answer * divisor, rhs: divisor, op: .division, answer: answer)
        case .expert:
            let answer = Int.random(in: 50...500); let divisor = Int.random(in: 2...50)
            return Question(lhs: answer * divisor, rhs: divisor, op: .division, answer: answer)
        }
    }

    // MARK: - Decimal Helpers

    func isClean(_ v: Double, maxDP: Int) -> Bool {
        let m = pow(10.0, Double(maxDP))
        let rounded = (abs(v) * m).rounded() / m
        return abs(abs(v) - rounded) < 1e-9
    }

    // MARK: - Decimal Question Dispatch

    func makeDecimalQuestion(op: Operation) -> Question {
        let resolvedOp: Operation = op == .mixed
            ? [Operation.addition, .subtraction, .multiplication, .division].randomElement()!
            : op
        let easy = selectedDifficulty == .easy
        let isHard = selectedDifficulty == .hard
        switch resolvedOp {
        case .addition:
            return isHard ? makeHardDecimalAddSub(isAddition: true)  : makeDecimalAddSub(isAddition: true,  easy: easy)
        case .subtraction:
            return isHard ? makeHardDecimalAddSub(isAddition: false) : makeDecimalAddSub(isAddition: false, easy: easy)
        case .multiplication:
            return isHard ? makeHardDecimalMul()                     : makeDecimalMul(easy: easy)
        case .division:
            return isHard ? makeHardDecimalDiv()                     : makeDecimalDiv(easy: easy)
        case .mixed:
            return makeDecimalAddSub(isAddition: true, easy: easy)
        }
    }

    // MARK: - Easy / Medium Decimal Generators

    func makeDecimalAddSub(isAddition: Bool, easy: Bool) -> Question {
        let tenths = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
        if easy {
            let a = Double(Int.random(in: 1...15)) + tenths.randomElement()!
            let b = Double(Int.random(in: 1...15)) + tenths.randomElement()!
            if isAddition {
                let ans = ((a + b) * 10).rounded() / 10
                return Question(lhs: a, rhs: b, op: .addition, answer: ans)
            } else {
                let bigger = max(a, b), smaller = min(a, b)
                let ans = ((bigger - smaller) * 10).rounded() / 10
                return Question(lhs: bigger, rhs: smaller, op: .subtraction, answer: ans)
            }
        } else {
            let twoDp = [0.05, 0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85, 0.95]
            let a = Double(Int.random(in: 10...99)) + tenths.randomElement()!
            let b = Double(Int.random(in: 1...20))  + twoDp.randomElement()!
            if isAddition {
                let ans = ((a + b) * 100).rounded() / 100
                return Question(lhs: a, rhs: b, op: .addition, answer: ans)
            } else {
                let bigger = max(a, b), smaller = min(a, b)
                let ans = ((bigger - smaller) * 100).rounded() / 100
                return Question(lhs: bigger, rhs: smaller, op: .subtraction, answer: ans)
            }
        }
    }

    func makeDecimalMul(easy: Bool) -> Question {
        if easy {
            let a = Double(Int.random(in: 2...12))
            let b = [0.5, 1.5, 2.5, 0.25, 0.75].randomElement()!
            let ans = (a * b * 100).rounded() / 100
            return Question(lhs: a, rhs: b, op: .multiplication, answer: ans)
        } else {
            let a = Double(Int.random(in: 10...50))
            let b = [0.1, 0.2, 0.25, 0.5, 0.75, 1.25].randomElement()!
            let ans = (a * b * 100).rounded() / 100
            return Question(lhs: a, rhs: b, op: .multiplication, answer: ans)
        }
    }

    func makeDecimalDiv(easy: Bool) -> Question {
        if easy {
            let answer = Double(Int.random(in: 2...12))
            let divisor = [0.5, 0.25, 2.0, 4.0, 5.0].randomElement()!
            let lhs = (answer * divisor * 100).rounded() / 100
            if isClean(lhs, maxDP: 2) { return Question(lhs: lhs, rhs: divisor, op: .division, answer: answer) }
        } else {
            let halfPart = [0.0, 0.5].randomElement()!
            let answer = Double(Int.random(in: 1...20)) + halfPart
            let divisor = [0.2, 0.25, 0.4, 0.5, 2.0, 4.0, 8.0].randomElement()!
            let lhs = (answer * divisor * 100).rounded() / 100
            if isClean(lhs, maxDP: 2) { return Question(lhs: lhs, rhs: divisor, op: .division, answer: answer) }
        }
        return makeDivision()
    }

    // MARK: - Hard Decimal Generators

    func makeHardDecimalAddSub(isAddition: Bool) -> Question {
        let tenths    = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
        let hundredths = [0.05, 0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85, 0.95]
        let fracA = Bool.random() ? hundredths.randomElement()! : tenths.randomElement()!
        let fracB = Bool.random() ? hundredths.randomElement()! : tenths.randomElement()!
        let a = Double(Int.random(in: 10...200)) + fracA
        let b = Double(Int.random(in: 10...200)) + fracB
        if isAddition {
            let ans = ((a + b) * 100).rounded() / 100
            return Question(lhs: a, rhs: b, op: .addition, answer: ans)
        } else {
            // Subtraction can yield a negative result
            let ans = ((a - b) * 100).rounded() / 100
            return Question(lhs: a, rhs: b, op: .subtraction, answer: ans)
        }
    }

    func makeHardDecimalMul() -> Question {
        for _ in 0..<10 {
            switch Int.random(in: 0...2) {
            case 0:
                // decimal × integer — e.g., 3,5 × 18 = 63
                let a = [0.5, 1.5, 2.5, 3.5, 4.5, 0.25, 0.75, 1.25, 2.25].randomElement()!
                let b = Double(Int.random(in: 2...50))
                let ans = (a * b * 100).rounded() / 100
                if isClean(ans, maxDP: 3) {
                    return Question(lhs: a, rhs: b, op: .multiplication, answer: ans)
                }
            case 1:
                // tenths × friendly decimal — e.g., 1,4 × 2,5 = 3,5
                let a = Double(Int.random(in: 1...25)) / 10.0
                let b = [0.5, 1.0, 1.5, 2.0, 2.5, 0.25, 0.75].randomElement()!
                let ans = (a * b * 1000).rounded() / 1000
                if isClean(ans, maxDP: 2) {
                    return Question(lhs: a, rhs: b, op: .multiplication, answer: ans)
                }
            default:
                // integer × hundredths — e.g., 24 × 0,75 = 18
                let a = Double(Int.random(in: 5...50))
                let b = [0.04, 0.08, 0.12, 0.15, 0.16, 0.24, 0.25, 0.32, 0.48].randomElement()!
                let ans = (a * b * 100).rounded() / 100
                if isClean(ans, maxDP: 2) {
                    return Question(lhs: a, rhs: b, op: .multiplication, answer: ans)
                }
            }
        }
        let (a, b) = mulRange()
        return Question(lhs: a, rhs: b, op: .multiplication, answer: a * b)
    }

    func makeHardDecimalDiv() -> Question {
        for _ in 0..<10 {
            let wholePart = Int.random(in: 1...30)
            let fracPart  = [0.0, 0.2, 0.25, 0.4, 0.5, 0.6, 0.75, 0.8].randomElement()!
            let answer    = Double(wholePart) + fracPart
            let divisor   = [0.5, 0.25, 2.0, 4.0, 5.0, 0.2, 0.4].randomElement()!
            let lhs       = answer * divisor
            if isClean(lhs, maxDP: 2) && isClean(answer, maxDP: 2) {
                return Question(lhs: (lhs * 100).rounded() / 100, rhs: divisor, op: .division, answer: answer)
            }
        }
        return makeDivision()
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
        finalScore = score
        finalAccuracy = accuracy
        timerActive = false; timerEnded = true
        gameTimer?.invalidate(); gameTimer = nil
        score = 0; streak = 0; totalAttempted = 0
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

// MARK: - Button Styles

struct GlassSmallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct GlassPlayAgainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 36)
            .padding(.vertical, 14)
            .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
        ArithmeticView(onBack: {})
    }
}
