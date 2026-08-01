import SwiftUI
import SwiftData
import UIKit

/// 寿司打風のタイムアタック・タイピング画面。
/// ソフトウェアキーボードから1文字ずつ受け取るため、実際に文字を表示するTextFieldは透明にし、
/// 見た目の単語表示は `TypingCharsView` が別途担当する（`onChange` で1文字ごとに判定→即クリアの繰り返し）。
struct TypingView: View {
    @Environment(\.modelContext) private var modelContext
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
            .toolbarColorScheme(viewModel.phase == .notStarted ? nil : .dark, for: .navigationBar)
            .task { viewModel.configure(context: modelContext) }
        }
        .tint(.cyan)
    }

    // MARK: - スタート画面

    private var startScreen: some View {
        VStack(spacing: 16) {
            Text("⌨️").font(.system(size: 48))
            Text("タイムアタック・タイピング")
                .font(.title2).bold()
            Text("制限時間\(TypingViewModel.sessionDuration)秒。1文字ずつ判定され、ミスすると同じ文字をやり直します。\n単語を打ち切ると自動で次の単語へ進み、残り時間にボーナスが加算されます。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("スタート") { viewModel.start() }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
        }
    }

    // MARK: - プレイ画面

    private var playingScreen: some View {
        VStack(spacing: 18) {
            timerBar

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE").font(.caption2).foregroundStyle(.gray)
                    Text("\(viewModel.score)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                        .contentTransition(.numericText())
                }
                Spacer()
                if viewModel.combo > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(comboLabel).font(.caption2).foregroundStyle(.gray)
                        Text("\(viewModel.combo)x")
                            .font(.system(size: comboFontSize, weight: .black, design: .rounded))
                            .foregroundStyle(comboColor)
                    }
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: viewModel.combo)
                }
            }

            Spacer(minLength: 0)

            if let word = viewModel.currentWord {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text(word.category.displayName)
                            .font(.caption2).bold()
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(categoryColor(word.category).opacity(0.25), in: Capsule())
                            .foregroundStyle(categoryColor(word.category))
                        Text(word.meaning)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }

                    TypingCharsView(word: word.word, charIndex: viewModel.charIndex, missFlash: viewModel.missFlash)
                        .id(viewModel.wordToken)

                    progressDots(word: word.word)
                }
            }

            Spacer(minLength: 0)

            Text("英字キーを入力")
                .font(.caption2)
                .foregroundStyle(.gray)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundStyle(.white)
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

    private var timerBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("残り時間").font(.caption).foregroundStyle(.gray)
                if viewModel.lastTimeBonus > 0 {
                    Text("+\(viewModel.lastTimeBonus)s")
                        .font(.caption).bold()
                        .foregroundStyle(.cyan)
                        .id(viewModel.wordToken)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                Text("\(viewModel.remainingSeconds)s")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(viewModel.remainingSeconds <= 10 ? .red : .white)
                    .contentTransition(.numericText())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(timerColor)
                        .frame(width: proxy.size.width * timerFraction)
                }
            }
            .frame(height: 8)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.remainingSeconds)
    }

    private var timerFraction: CGFloat {
        CGFloat(viewModel.remainingSeconds) / CGFloat(TypingViewModel.sessionDuration)
    }

    private var timerColor: Color {
        if viewModel.remainingSeconds > 30 { return .green }
        if viewModel.remainingSeconds > 15 { return .yellow }
        return .red
    }

    private var comboLabel: String {
        switch viewModel.combo {
        case 20...: return "🔥 ULTRA COMBO"
        case 10..<20: return "GREAT COMBO"
        case 5..<10: return "COMBO"
        default: return "combo"
        }
    }

    private var comboColor: Color {
        switch viewModel.combo {
        case 20...: return .red
        case 10..<20: return .orange
        case 5..<10: return .yellow
        default: return .white
        }
    }

    private var comboFontSize: CGFloat {
        switch viewModel.combo {
        case 20...: return 40
        case 10..<20: return 34
        case 5..<10: return 28
        default: return 22
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
        if index == viewModel.charIndex { return .white }
        return .gray.opacity(0.4)
    }
}

/// 単語を1文字ずつ、進捗に応じて色分け表示する（入力済み=緑／現在位置=白+シアン下線、ミス時は赤フラッシュ／未入力=グレー）
private struct TypingCharsView: View {
    let word: String
    let charIndex: Int
    let missFlash: Bool

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(word.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(color(for: index))
                    .overlay(alignment: .bottom) {
                        if index == charIndex {
                            Rectangle()
                                .fill(missFlash ? Color.red : Color.cyan)
                                .frame(height: 3)
                                .offset(y: 4)
                        }
                    }
            }
        }
    }

    private func color(for index: Int) -> Color {
        if index < charIndex { return .green }
        if index == charIndex { return missFlash ? .red : .white }
        return .gray
    }
}

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
