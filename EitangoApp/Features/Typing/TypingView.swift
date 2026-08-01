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
                        onRetry: { viewModel.start() }
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
            }
            .task { viewModel.configure(context: modelContext) }
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
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            Text("タイムアタック・タイピング")
                .font(.title2).bold()
            Text("制限時間\(TypingViewModel.sessionDuration)秒。1文字ずつ判定され、ミスすると同じ文字をやり直します。\n単語を打ち切ると自動で次の単語へ進み、残り時間にボーナスが加算されます。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("スタート") { viewModel.start() }
                .buttonStyle(.borderedProminent)
        }
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
            if isFlashing { Haptics.error() }
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

            TypingCharsView(word: word.word, charIndex: viewModel.charIndex, missFlash: viewModel.missFlash)
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

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, character in
                Text(String(character))
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

    private func color(for index: Int) -> Color {
        if index < charIndex { return .green }
        if index == charIndex { return missFlash ? .red : .primary }
        return .secondary
    }
}

@MainActor
private enum Haptics {
    static func success() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

#Preview {
    TypingView()
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self], inMemory: true)
}
