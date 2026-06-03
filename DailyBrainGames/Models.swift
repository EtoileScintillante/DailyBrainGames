//
//  Models.swift
//  DailyBrainGames
//
//  Created by Esma Zuurbier on 29/05/2026.
//

import SwiftUI

// MARK: - Enums

/// Arithmetic operation modes used by the Arithmetic game.
///
/// The `mixed` case is a picker option rather than a concrete question
/// operation; generated mixed questions still store the actual operation used.
enum Operation: String, CaseIterable, Identifiable {
    case addition = "Addition"
    case subtraction = "Subtraction"
    case multiplication = "Multiplication"
    case division = "Division"
    case mixed = "Mixed"

    var id: String { rawValue }

    /// Symbol displayed inside arithmetic questions.
    var symbol: String {
        switch self {
        case .addition:       return "+"
        case .subtraction:    return "−"
        case .multiplication: return "×"
        case .division:       return "÷"
        case .mixed:          return "?"
        }
    }
}

/// Difficulty presets for the Arithmetic game.
///
/// The selected difficulty is interpreted by the question generator in
/// `ArithmeticView`.
enum Difficulty: String, CaseIterable, Identifiable {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"
    case expert = "Expert"

    var id: String { rawValue }
}

/// Shared timer options used by the timed game modes.
enum TimerMode: String, CaseIterable, Identifiable {
    case untimed = "Untimed"
    case sixty   = "60 sec"
    case twoMin  = "2 min"

    var id: String { rawValue }

    /// Duration in seconds for timed modes, or `nil` when the game is untimed.
    var seconds: Int? {
        switch self {
        case .untimed: return nil
        case .sixty:   return 60
        case .twoMin:  return 120
        }
    }
}

/// Visual theme selected from the Home screen.
///
/// A theme controls both the background image and the accent color used by
/// feedback text, selected controls, and highlighted borders.
enum Theme: String, CaseIterable, Identifiable {
    case purple = "Purple"
    case blue   = "Blue"
    case red    = "Red"
    case yellow = "Yellow"
    case green  = "Green"

    var id: String { rawValue }

    /// Background image file bundled with the app.
    var imageName: String {
        switch self {
        case .purple: return "purple.jpg"
        case .blue:   return "blue.jpg"
        case .red:    return "red.jpg"
        case .yellow: return "yellow.jpg"
        case .green:  return "green.jpg"
        }
    }

    /// Accent color for selected UI, success feedback, and active input borders.
    var accent: Color {
        switch self {
        case .purple: return Color(red: 0.70, green: 0.45, blue: 1.00)
        case .blue:   return Color(red: 0.38, green: 0.68, blue: 1.00)
        case .red:    return Color(red: 1.00, green: 0.42, blue: 0.42)
        case .yellow: return Color(red: 1.00, green: 0.82, blue: 0.28)
        case .green:  return Color(red: 0.35, green: 0.90, blue: 0.50)
        }
    }
}

// MARK: - Make Target

/// One card in a Make Target puzzle.
///
/// Cards begin as plain numbers. When the player combines cards, `expression`
/// tracks the arithmetic expression that produced the current `value`.
struct MakeTargetCard: Identifiable {
    /// Stable identity used by SwiftUI lists and by selection state.
    let id: UUID
    /// Current numeric value of the card.
    let value: Int
    /// Expression shown on the card, such as `4` or `(4 × 3)`.
    let expression: String

    /// Creates a Make Target card.
    ///
    /// - Parameters:
    ///   - value: Numeric value represented by the card.
    ///   - expression: Optional display expression. Defaults to the value text.
    init(value: Int, expression: String? = nil) {
        self.id = UUID()
        self.value = value
        self.expression = expression ?? "\(value)"
    }
}

/// Generated Make Target puzzle metadata.
struct MakeTargetPuzzle {
    /// Number the player is trying to reach.
    let target: Int
    /// One known solution, used when showing help or revealing an answer.
    let solutionExpression: String
}

/// Difficulty presets for Make Target.
///
/// Difficulty controls the available operators, card number range, target
/// range, and whether intermediate card values stay visible.
enum MakeTargetDifficulty: String, CaseIterable, Identifiable {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"
    case expert = "Expert"

    var id: String { rawValue }

    /// Number of cards dealt for each puzzle.
    var cardCount: Int { 4 }

    /// Operators the player may use at this difficulty.
    ///
    /// Hard reuses Medium's operator set, while Expert adds division.
    var allowedOperators: [String] {
        switch self {
        case .easy:          return ["+", "−"]
        case .medium, .hard: return ["+", "−", "×"]
        case .expert:        return ["+", "−", "×", "÷"]
        }
    }

    /// Range used when generating the starting number cards.
    var numberRange: ClosedRange<Int> {
        switch self {
        case .easy:          return 1...15
        case .medium, .hard: return -20...20
        case .expert:        return -30...30
        }
    }

    /// Accepted range for generated target values.
    var targetRange: ClosedRange<Int> {
        switch self {
        case .easy:          return 1...60
        case .medium, .hard: return -150...150
        case .expert:        return -200...200
        }
    }

    /// Whether combined cards show their numeric value as part of the expression preview.
    ///
    /// Hard and Expert hide intermediate values so the player has to reason from
    /// expressions instead of seeing every computed result.
    var showsValues: Bool {
        switch self {
        case .easy, .medium: return true
        case .hard, .expert: return false
        }
    }
}

// MARK: - Question

/// Formats a number for arithmetic display.
///
/// Values are rounded to two decimal places, trimmed with `%g`, and displayed
/// with a comma decimal separator to match keypad input.
func formatNum(_ v: Double) -> String {
    let r = (v * 100).rounded() / 100
    let g = String(format: "%.10g", r)
    return g.replacingOccurrences(of: ".", with: ",")
}

/// One generated Arithmetic question.
struct Question {
    /// Left-hand side value shown before the operator.
    let lhs: Double
    /// Right-hand side value shown after the operator.
    let rhs: Double
    /// Concrete operation used by this question.
    let op: Operation
    /// Correct numeric answer.
    let answer: Double

    /// Convenience initializer for integer-only questions.
    init(lhs: Int, rhs: Int, op: Operation, answer: Int) {
        self.lhs = Double(lhs); self.rhs = Double(rhs)
        self.op = op; self.answer = Double(answer)
    }

    /// Creates a question that may include decimal values.
    init(lhs: Double, rhs: Double, op: Operation, answer: Double) {
        self.lhs = lhs; self.rhs = rhs
        self.op = op; self.answer = answer
    }

    /// User-facing question text, such as `8 × 7`.
    var display: String { "\(formatNum(lhs)) \(op.symbol) \(formatNum(rhs))" }
}
