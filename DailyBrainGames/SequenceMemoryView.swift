//
//  SequenceMemoryView.swift
//  DailyBrainGames
//
//  Created by Esma Zuurbier on 02/06/2026.
//

import SwiftUI

/// Interactive sequence memory game screen.
///
/// The game shows an expanding tile sequence. The player repeats the sequence
/// from memory, earning one point for each completed round.
struct SequenceMemoryView: View {
    /// Called by the custom back button to return to Home.
    let onBack: () -> Void

    @AppStorage("selectedTheme") private var selectedTheme: Theme = .purple
    /// Persisted best score for the 3x3 grid.
    @AppStorage("sequenceMemoryHighScore") private var highScore3x3: Int = 0
    /// Persisted best score for the 4x4 grid.
    @AppStorage("sequenceMemoryHighScore4x4") private var highScore4x4: Int = 0
    /// Persisted grid-size toggle.
    @AppStorage("sequenceMemory4x4") private var is4x4: Bool = false

    /// How long each sequence tile stays lit during playback.
    private let tileLitDuration: Double = 0.65
    /// Pause between lit tiles during playback.
    private let tileGapDuration: Double = 0.22
    /// Pause between countdown numbers.
    private let countdownInterval: Double = 0.8
    /// Pause after countdown before sequence playback begins.
    private let postCountdownPause: Double = 1.0
    /// Pause between a completed round and the next sequence playback.
    private let betweenRoundPause: Double = 1.0
    /// Base pause after the player completes a round correctly.
    private let correctFlashDuration: Double = 0.25

    /// Full generated sequence of tile indexes for the current run.
    @State private var sequence: [Int] = []
    /// Number of correct taps entered in the current round.
    @State private var playerInputCount: Int = 0
    /// Completed rounds in the current run.
    @State private var score: Int = 0
    /// Current phase of the game state machine.
    @State private var gamePhase: GamePhase = .idle
    /// Tile currently lit during playback.
    @State private var litTile: Int? = nil
    /// Tile flashed red after an incorrect tap.
    @State private var wrongTile: Int? = nil
    /// Tile flashed green after a correct tap.
    @State private var greenTile: Int? = nil
    /// Current countdown number shown before playback starts.
    @State private var countdownValue: Int = 3
    /// Whether the game-over modal is visible.
    @State private var showGameOver: Bool = false
    /// Async task currently driving countdown, playback, or delayed transitions.
    @State private var currentTask: Task<Void, Never>? = nil
    /// Controls the initial fade-in for the board and controls.
    @State private var appeared: Bool = false

    /// Phases for the sequence memory state machine.
    private enum GamePhase { case idle, countdown, showing, input, roundComplete, gameOver }

    /// Number of tiles in the active grid.
    private var tileCount: Int { is4x4 ? 16 : 9 }
    /// Number of columns in the active grid.
    private var gridColumns: Int { is4x4 ? 4 : 3 }
    private var tileCornerRadius: CGFloat { is4x4 ? 12 : 16 }
    private var gridSpacing: CGFloat { is4x4 ? 8 : 12 }
    private var gridPadding: CGFloat { is4x4 ? 20 : 28 }
    /// Whether a run is in progress and can be stopped.
    private var gameIsActive: Bool { gamePhase != .idle && gamePhase != .gameOver }

    /// Best score for the active grid size.
    private var activeHighScore: Int {
        get { is4x4 ? highScore4x4 : highScore3x3 }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerArea
            mainArea
                .opacity(appeared ? 1 : 0)
            controlsArea
                .opacity(appeared ? 1 : 0)
        }
        .safeAreaPadding([.top, .bottom])
        .overlay {
            if showGameOver {
                gameOverOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showGameOver)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeIn(duration: 0.18)) { appeared = true }
            }
        }
        .onDisappear { cancelCurrentTask() }
    }

    // MARK: - Header

    var headerArea: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Sequence")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        stopAndReset()
                        onBack()
                    } label: {
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
            .padding(.bottom, 12)

            HStack(spacing: 0) {
                statView(label: "Score", value: "\(score)")
                statDivider
                statView(label: "Best",  value: "\(activeHighScore)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    is4x4.toggle()
                    stopAndReset()
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(is4x4 ? selectedTheme.accent : Color.white.opacity(0.35))
                            .frame(width: 8, height: 8)
                        Text("4×4")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: Capsule())
                    .overlay {
                        if is4x4 {
                            Capsule().strokeBorder(selectedTheme.accent, lineWidth: 2)
                        }
                    }
                }
                .disabled(gameIsActive)
                .opacity(gameIsActive ? 0.4 : 1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Main

    var mainArea: some View {
        VStack(spacing: 20) {
            Spacer()

            statusView
                .frame(height: 56)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: gridColumns),
                spacing: gridSpacing
            ) {
                ForEach(0..<tileCount, id: \.self) { index in
                    tileView(index: index)
                }
            }
            .padding(.horizontal, gridPadding)
            .animation(.easeInOut(duration: 0.25), value: is4x4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    var statusView: some View {
        switch gamePhase {
        case .idle:
            Text("Press Start to play")
                .font(.system(size: 25, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
        case .countdown:
            Text("\(countdownValue)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.15), value: countdownValue)
        case .showing:
            Text("Watch!")
                .font(.system(size: 25, weight: .semibold))
                .foregroundColor(.white.opacity(0.65))
        case .input, .roundComplete:
            Text("Your turn!")
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(selectedTheme.accent)
        case .gameOver:
            Text(" ")
                .font(.system(size: 20))
        }
    }

    // MARK: - Tile

    /// Builds one tappable tile in the sequence grid.
    ///
    /// The tile's visual state is driven by `litTile`, `wrongTile`, and
    /// `greenTile`, while taps are accepted only during the input phase.
    func tileView(index: Int) -> some View {
        let isLit   = litTile   == index
        let isWrong = wrongTile == index
        let isGreen = greenTile == index
        let shape   = RoundedRectangle(cornerRadius: tileCornerRadius)

        return Button {
            guard gamePhase == .input else { return }
            handleTileTap(index: index)
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
        }
        .glassEffect(isLit ? .regular.interactive(true) : .regular, in: shape)
        .overlay {
            if isLit {
                shape.fill(Color(red: 0.35, green: 0.75, blue: 1.0).opacity(0.5))
            } else if isWrong {
                shape.fill(Color.red.opacity(0.4))
            } else if isGreen {
                shape.fill(Color(red: 0.2, green: 0.85, blue: 0.45).opacity(0.45))
            }
        }
        .overlay {
            if isLit {
                shape.strokeBorder(Color(red: 0.45, green: 0.82, blue: 1.0), lineWidth: 3)
            } else if isWrong {
                shape.strokeBorder(Color(red: 1.0, green: 0.35, blue: 0.35), lineWidth: 3)
            } else if isGreen {
                shape.strokeBorder(Color(red: 0.2, green: 0.9, blue: 0.45), lineWidth: 3)
            } else {
                shape.strokeBorder(selectedTheme.accent.opacity(0.4), lineWidth: 1.5)
            }
        }
        .scaleEffect(isLit ? 1.06 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isLit)
        .animation(.easeInOut(duration: 0.15), value: isWrong)
        .animation(.easeInOut(duration: 0.15), value: isGreen)
    }

    // MARK: - Controls

    var controlsArea: some View {
        let isActive = gameIsActive
        return Button {
            if isActive { stopAndReset() } else { startGame() }
        } label: {
            Text(isActive ? "Stop" : "Start")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
        }
        .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 13))
        .disabled(gamePhase == .gameOver)
        .opacity(gamePhase == .gameOver ? 0.35 : 1)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Game Over Overlay

    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Game Over")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                VStack(spacing: 6) {
                    Text("Score: \(score)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Text("Best: \(activeHighScore)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Button("Close") { closeGameOver() }
                    .buttonStyle(GlassPlayAgainButtonStyle())
            }
            .padding(32)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Game Logic

    /// Starts a fresh run with a countdown, then begins the first round.
    ///
    /// The countdown and follow-up transition are driven by `currentTask` so the
    /// sequence can be cancelled cleanly if the player stops or leaves the view.
    private func startGame() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sequence = []
        playerInputCount = 0
        litTile = nil
        wrongTile = nil
        cancelCurrentTask()
        countdownValue = 3
        gamePhase = .countdown

        currentTask = Task {
            for i in stride(from: 3, through: 1, by: -1) {
                if Task.isCancelled { return }
                countdownValue = i
                try? await Task.sleep(nanoseconds: UInt64(countdownInterval * 1_000_000_000))
            }
            if Task.isCancelled { return }
            gamePhase = .showing
            try? await Task.sleep(nanoseconds: UInt64(postCountdownPause * 1_000_000_000))
            if Task.isCancelled { return }
            nextRound()
        }
    }

    /// Adds one tile to the sequence and starts playback for the new round.
    ///
    /// Consecutive duplicate tiles are avoided so the sequence is easier to read.
    private func nextRound() {
        let newTile: Int
        if let last = sequence.last {
            var candidate: Int
            repeat { candidate = Int.random(in: 0..<tileCount) } while candidate == last
            newTile = candidate
        } else {
            newTile = Int.random(in: 0..<tileCount)
        }
        sequence.append(newTile)
        playerInputCount = 0

        cancelCurrentTask()
        currentTask = Task { await showSequence() }
    }

    /// Plays the full sequence by lighting each tile in order.
    ///
    /// When playback finishes, the game moves to the input phase so the player
    /// can repeat the sequence.
    private func showSequence() async {
        gamePhase = .showing
        for tile in sequence {
            if Task.isCancelled { return }
            litTile = tile
            try? await Task.sleep(nanoseconds: UInt64(tileLitDuration * 1_000_000_000))
            if Task.isCancelled { return }
            litTile = nil
            try? await Task.sleep(nanoseconds: UInt64(tileGapDuration * 1_000_000_000))
            if Task.isCancelled { return }
        }
        gamePhase = .input
    }

    /// Handles one player tile tap during the input phase.
    ///
    /// Correct taps advance through the sequence and flash green. Completing the
    /// full sequence updates score/high score and schedules the next round.
    /// Incorrect taps end the run and show the game-over overlay.
    private func handleTileTap(index: Int) {
        guard playerInputCount < sequence.count else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if index == sequence[playerInputCount] {
            greenTile = index
            Task {
                try? await Task.sleep(nanoseconds: 250_000_000)
                greenTile = nil
            }
            playerInputCount += 1
            if playerInputCount == sequence.count {
                score += 1
                if is4x4 {
                    if score > highScore4x4 { highScore4x4 = score }
                } else {
                    if score > highScore3x3 { highScore3x3 = score }
                }
                gamePhase = .roundComplete
                cancelCurrentTask()
                currentTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(correctFlashDuration * 1_500_000_000))
                    if Task.isCancelled { return }
                    gamePhase = .showing
                    try? await Task.sleep(nanoseconds: UInt64(betweenRoundPause * 1_000_000_000))
                    if Task.isCancelled { return }
                    nextRound()
                }
            }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            gamePhase = .gameOver
            wrongTile = index
            cancelCurrentTask()
            currentTask = Task {
                try? await Task.sleep(nanoseconds: 700_000_000)
                if Task.isCancelled { return }
                wrongTile = nil
                withAnimation(.easeInOut(duration: 0.2)) { showGameOver = true }
            }
        }
    }

    /// Stops the current run and returns the screen to its idle state.
    private func stopAndReset() {
        cancelCurrentTask()
        litTile = nil
        wrongTile = nil
        greenTile = nil
        sequence = []
        playerInputCount = 0
        score = 0
        showGameOver = false
        gamePhase = .idle
    }

    /// Dismisses the game-over overlay and clears the finished run.
    private func closeGameOver() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) { showGameOver = false }
        score = 0
        sequence = []
        playerInputCount = 0
        litTile = nil
        wrongTile = nil
        greenTile = nil
        gamePhase = .idle
    }

    /// Cancels any async sequence/countdown task currently in flight.
    private func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Helpers

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
}

#Preview {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.14).ignoresSafeArea()
        SequenceMemoryView(onBack: {})
    }
}
