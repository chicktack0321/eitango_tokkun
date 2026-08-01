import SwiftUI
import SwiftData
import UIKit

/// 寿司打風のタイムアタック・タイピング画面。
/// ソフトウェアキーボードから1文字ずつ受け取るため、実際に文字を表示するTextFieldは透明にし、
/// 見た目の単語表示は `TypingCharsView` が別途担当する（`onChange` で1文字ごとに判定→即クリアの繰り返し）。
/// 配色・カードレイアウトはHome/単語帳/クイズと同じ標準iOS配色（システム背景・カード）に揃えている。
struct TypingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = TypingViewModel()
    @State private var inputBuffer = ""
    /// 音のオン・オフは端末に覚えさせる（毎回切り直すのは煩わしいため）
    @AppStorage("typingSoundEnabled") private var isSoundEnabled = true
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .notStarted:
                    startScreen
                case .inProgress:
                    playingScreen
                case .finished:
                    TypingResultView(
                        score: viewModel.score,
                        correctWordCount: viewModel.correctWordCount,
                        missCount: viewModel.missCount,
                        maxCombo: viewModel.maxCombo,
                        accuracy: viewModel.accuracy,
                        mode: viewModel.mode,
                        achievement: viewModel.achievement,
                        bestScores: viewModel.bestScores,
                        onRetry: { viewModel.start(mode: viewModel.mode) }
                    )
                }
            }
            .navigationTitle("タイピングテスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.phase == .inProgress {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("やめる") { viewModel.abortSession() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        GameAudio.shared.isEnabled.toggle()
                        isSoundEnabled = GameAudio.shared.isEnabled
                        if isSoundEnabled, viewModel.phase == .inProgress {
                            GameAudio.shared.startBGM()
                        }
                    } label: {
                        Image(systemName: isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .accessibilityLabel(isSoundEnabled ? "音を消す" : "音を出す")
                }
            }
            .task {
                viewModel.configure(context: modelContext)
                GameAudio.shared.isEnabled = isSoundEnabled
            }
            // 画面を離れている間に制限時間が減り続けないようにする
            .onDisappear { viewModel.suspendTimer() }
            .onAppear { viewModel.resumeTimer() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.resumeTimer()
                } else {
                    viewModel.suspendTimer()
                }
            }
        }
    }

    // MARK: - スタート画面

    private var startScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    Text("タイムアタック・タイピング")
                        .font(.title3).bold()
                    Text("制限時間\(TypingViewModel.sessionDuration)秒。1文字ずつ判定され、ミスすると同じ文字をやり直します。単語を打ち切ると自動で次へ進み、残り時間にボーナスが加算されます。")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)

                DashboardCard(title: "モードを選ぶ") {
                    VStack(spacing: 10) {
                        ForEach(TypingViewModel.Mode.allCases) { mode in
                            Button {
                                viewModel.start(mode: mode)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: mode == .hidden ? "eye.slash.fill" : "eye.fill")
                                        .foregroundStyle(mode == .hidden ? .purple : .blue)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.displayName)
                                            .font(.subheadline).bold()
                                        Text(mode.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !viewModel.bestScores.isEmpty {
                    TypingBestScoreCard(scores: viewModel.bestScores, highlightedIndex: nil)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - プレイ画面

    private var playingScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                timerCard
                scoreCard
                if let word = viewModel.currentWord {
                    wordCard(word: word)
                }
                Text("英字キーを入力")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            TextField("", text: $inputBuffer)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($inputFocused)
                .opacity(0.01)
        }
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = true }
        .onAppear { inputFocused = true }
        .onChange(of: inputBuffer) { _, newValue in
            guard !newValue.isEmpty else { return }
            for char in newValue {
                viewModel.inputCharacter(char)
            }
            inputBuffer = ""
        }
        .onChange(of: viewModel.wordToken) { _, _ in
            Haptics.success()
        }
        .onChange(of: viewModel.missFlash) { _, isFlashing in
            if isFlashing { Haptics.failure() }
        }
    }

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("残り時間")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if viewModel.lastTimeBonus > 0 {
                    Text("+\(viewModel.lastTimeBonus)s")
                        .font(.caption).bold()
                        .foregroundStyle(.blue)
                        .id(viewModel.wordToken)
                }
                Spacer()
                Text("\(viewModel.remainingSeconds)秒")
                    .font(.title2).bold()
                    .foregroundStyle(viewModel.remainingSeconds <= 10 ? .red : .primary)
                    .contentTransition(.numericText())
            }
            ProgressView(value: Double(viewModel.remainingSeconds), total: Double(TypingViewModel.sessionDuration))
                .tint(timerColor)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.3), value: viewModel.remainingSeconds)
    }

    private var timerColor: Color {
        if viewModel.remainingSeconds > 30 { return .green }
        if viewModel.remainingSeconds > 15 { return .orange }
        return .red
    }

    private var scoreCard: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(viewModel.score)", label: "SCORE", tint: .blue)
            StatTile(
                value: "\(viewModel.combo)x",
                label: viewModel.combo > 0 ? comboLabel : "COMBO",
                tint: viewModel.combo > 0 ? comboColor : .secondary
            )
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: viewModel.combo)
    }

    private func wordCard(word: WordMaster) -> some View {
        VStack(spacing: 18) {
            HStack {
                Text(word.category.displayName)
                    .font(.caption2).bold()
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(categoryColor(word.category).opacity(0.15), in: Capsule())
                    .foregroundStyle(categoryColor(word.category))
                Spacer()
            }
            Text(word.meaning)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            TypingCharsView(
                word: word.word,
                charIndex: viewModel.charIndex,
                missFlash: viewModel.missFlash,
                hidesUntyped: viewModel.mode == .hidden
            )
                .id(viewModel.wordToken)

            progressDots(word: word.word)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var comboLabel: String {
        switch viewModel.combo {
        case 20...: return "🔥 ULTRA COMBO"
        case 10..<20: return "GREAT COMBO"
        default: return "COMBO"
        }
    }

    private var comboColor: Color {
        switch viewModel.combo {
        case 20...: return .red
        case 10..<20: return .orange
        default: return .blue
        }
    }

    private func categoryColor(_ category: FrequencyRank) -> Color {
        switch category {
        case .a: return .red
        case .b: return .blue
        case .c: return .green
        }
    }

    private func progressDots(word: String) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, _ in
                Circle()
                    .fill(dotColor(index: index))
                    .frame(width: index == viewModel.charIndex ? 8 : 6, height: index == viewModel.charIndex ? 8 : 6)
            }
        }
    }

    private func dotColor(index: Int) -> Color {
        if index < viewModel.charIndex { return .green }
        if index == viewModel.charIndex { return .blue }
        return Color(.systemGray4)
    }
}

/// 単語を1文字ずつ、進捗に応じて色分け表示する（入力済み=緑／現在位置=青の下線／ミス時は赤フラッシュ／未入力=グレー）
private struct TypingCharsView: View {
    let word: String
    let charIndex: Int
    let missFlash: Bool
    /// かくれんぼモード。まだ打っていない文字を伏せ字にする。
    var hidesUntyped: Bool = false

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, character in
                Text(display(character, at: index))
                    .font(.system(size: 40, weight: .black, design: .monospaced))
                    .foregroundStyle(color(for: index))
                    .overlay(alignment: .bottom) {
                        if index == charIndex {
                            Rectangle()
                                .fill(missFlash ? Color.red : Color.blue)
                                .frame(height: 3)
                                .offset(y: 4)
                        }
                    }
            }
        }
    }

    /// かくれんぼでは打ち終えた文字だけを見せる。現在位置も伏せたままにして、
    /// 訳語から綴りを思い出す練習になるようにする。
    private func display(_ character: Character, at index: Int) -> String {
        guard hidesUntyped, index >= charIndex else { return String(character) }
        return "_"
    }

    private func color(for index: Int) -> Color {
        if index < charIndex { return .green }
        if index == charIndex { return missFlash ? .red : .primary }
        return .secondary
    }
}

#Preview {
    TypingView()
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self], inMemory: true)
}
