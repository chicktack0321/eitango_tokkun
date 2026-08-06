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
    /// 出題範囲。4択クイズと同じ設定を共有する
    @State private var scope = StudySettings.studyScope
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
                    SoundToggleButton(isSessionActive: viewModel.phase == .inProgress)
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

                StudyScopeCard(
                    title: "出題範囲",
                    scope: $scope,
                    matchingCount: viewModel.scopeWordCount,
                    hasUserWords: viewModel.hasUserWords,
                    showsPronunciationOption: true,
                    // ブラインドは綴りを思い出す練習なので、読み上げると答えを言ってしまう
                    pronunciationNote: "ブラインドでは読み上げません（綴りの手がかりになってしまうため）"
                )

                if !viewModel.bestScores.isEmpty {
                    TypingBestScoreCard(scores: viewModel.bestScores, highlightedIndex: nil)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        // 範囲は4択クイズと共有している。変えたら語数の表示をすぐ合わせる
        .onChange(of: scope) { _, newValue in
            StudySettings.studyScope = newValue
            viewModel.refreshScopeCount()
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
        // 出題された語の発音を聞かせる。ブラインドでは綴りの手がかりになってしまうので出さない。
        // currentWord を見ているので、開始直後の1語目にも効く。
        .onChange(of: viewModel.currentWord?.wordId, initial: true) { _, wordId in
            guard viewModel.mode == .normal, wordId != nil,
                  let word = viewModel.currentWord?.word else { return }
            WordPronouncer.shared.speak(word)
        }
        .onDisappear { WordPronouncer.shared.stop() }
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
        // 文字数ぶん並ぶので、自分で追加した長い語でもはみ出さないよう折り返す
        WrappingHStack(spacing: 6, lineSpacing: 6) {
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
    /// ブラインドモード。まだ打っていない文字を伏せ字にする。
    var hidesUntyped: Bool = false

    var body: some View {
        // 収録語は最長23文字（artificial intelligence）で、この文字サイズだと
        // iPhoneの幅には1行で収まらない。HStackのままだと文字が潰れて重なるため折り返す。
        WrappingHStack(spacing: 1, lineSpacing: 6) {
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

    /// ブラインドでは打ち終えた文字だけを見せる。現在位置も伏せたままにして、
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

/// 子を左から並べ、幅に入らなくなったら次の行へ折り返す。各行は中央に寄せる。
///
/// 1文字ずつ色と下線を変える必要があって `Text` をひとつにまとめられないため、
/// 標準の折り返しが使えない。`HStack` に任せると幅が足りないぶん文字が潰れて重なる。
private struct WrappingHStack: Layout {
    var spacing: CGFloat = 1
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let advance = current.indices.isEmpty ? size.width : size.width + spacing
            // 1文字でも幅を超える場合に無限に改行しないよう、行頭の1文字は必ず載せる
            if !current.indices.isEmpty, current.width + advance > maxWidth {
                rows.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width += advance
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#Preview {
    TypingView()
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self], inMemory: true)
}
