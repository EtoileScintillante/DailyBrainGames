//
//  Models.swift
//  DailyMentalMath
//
//  Created by Esma Zuurbier on 29/05/2026.
//

import SwiftUI

// MARK: - Enums

enum Operation: String, CaseIterable, Identifiable {
    case addition = "Addition"
    case subtraction = "Subtraction"
    case multiplication = "Multiplication"
    case division = "Division"
    case mixed = "Mixed"

    var id: String { rawValue }

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

enum Difficulty: String, CaseIterable, Identifiable {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"
    case expert = "Expert"

    var id: String { rawValue }
}

enum TimerMode: String, CaseIterable, Identifiable {
    case untimed = "Untimed"
    case sixty   = "60 sec"
    case twoMin  = "2 min"

    var id: String { rawValue }

    var seconds: Int? {
        switch self {
        case .untimed: return nil
        case .sixty:   return 60
        case .twoMin:  return 120
        }
    }
}

enum Theme: String, CaseIterable, Identifiable {
    case purple = "Purple"
    case blue   = "Blue"
    case red    = "Red"
    case gold   = "Gold"

    var id: String { rawValue }

    var imageName: String {
        switch self {
        case .purple: return "wallpaper_purple"
        case .blue:   return "wallpaper_blue.PNG"
        case .red:    return "wallpaper_red.PNG"
        case .gold:   return "wallpaper_gold.PNG"
        }
    }

    // UI accent — borders, "Correct ✓" text, minus/decimals active border
    var accent: Color {
        switch self {
        case .purple: return Color(red: 0.70, green: 0.45, blue: 1.00)
        case .blue:   return Color(red: 0.38, green: 0.68, blue: 1.00)
        case .red:    return Color(red: 1.00, green: 0.42, blue: 0.42)
        case .gold:   return Color(red: 1.00, green: 0.82, blue: 0.28)
        }
    }
}

// MARK: - Make Target

struct MakeTargetCard: Identifiable {
    let id: UUID
    let value: Int
    let expression: String

    init(value: Int, expression: String? = nil) {
        self.id = UUID()
        self.value = value
        self.expression = expression ?? "\(value)"
    }
}

struct MakeTargetPuzzle {
    let target: Int
    let solutionExpression: String
}

enum MakeTargetDifficulty: String, CaseIterable, Identifiable {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    var id: String { rawValue }

    var cardCount: Int { 4 }

    var allowedOperators: [String] {
        switch self {
        case .easy:   return ["+", "−"]
        case .medium: return ["+", "−", "×"]
        case .hard:   return ["+", "−", "×", "÷"]
        }
    }

    var numberRange: ClosedRange<Int> {
        switch self {
        case .easy:   return 1...15
        case .medium: return -20...20
        case .hard:   return -30...30
        }
    }

    var targetRange: ClosedRange<Int> {
        switch self {
        case .easy:   return 1...60
        case .medium: return -150...150
        case .hard:   return -200...200
        }
    }
}

// MARK: - Question

// Formats a Double for display using comma as decimal separator, no trailing zeros
func formatNum(_ v: Double) -> String {
    let r = (v * 100).rounded() / 100
    let g = String(format: "%.10g", r)
    return g.replacingOccurrences(of: ".", with: ",")
}

struct Question {
    let lhs: Double
    let rhs: Double
    let op: Operation
    let answer: Double

    // Convenience initializer for integer questions
    init(lhs: Int, rhs: Int, op: Operation, answer: Int) {
        self.lhs = Double(lhs); self.rhs = Double(rhs)
        self.op = op; self.answer = Double(answer)
    }

    init(lhs: Double, rhs: Double, op: Operation, answer: Double) {
        self.lhs = lhs; self.rhs = rhs
        self.op = op; self.answer = answer
    }

    var display: String { "\(formatNum(lhs)) \(op.symbol) \(formatNum(rhs))" }
}
