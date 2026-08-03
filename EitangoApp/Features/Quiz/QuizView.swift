import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TabRouter.self) private var router
    @State private var viewModel = QuizViewModel()
    /// 正解のたびに増やして紙吹雪を発生させる
    @State private var celebrationTrigger = 0
    @State private var entitlements = Entitlements.shared
    @State private var isShowingPaywall = false
    /// 出題範囲。保存先は StudySettings（ViewModel からも読むため UserDefaults に置いている）
    @State private var scope = StudySettings.studyScope

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .notStarted:
                    startScreen
                case .inProgress:
                    if let question = viewModel.currentQuestion {
                        quizScreen(question: question)
                    }
                case .finished:
                    QuizResultView(
                        summary: viewModel.resultSummary,
                        onRetry: { viewModel.startNewQuiz(scope: viewModel.scope) },
                        onBackToStart: { viewModel.returnToStart() }
                    )
                }
            }
            .navigationTitle(viewModel.phase == .notStarted ? "4択クイズ" : viewModel.scope.title)
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
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
            }
            .task { viewModel.configure(context: modelContext) }
            // ホームの「復習する単語がN語あります」から来たときは、押した通りに復習だけを始める
            .onChange(of: router.pendingQuizScope) { _, scope in
                guard scope != nil, let requested = router.consumePendingQuizScope() else { return }
                viewModel.startNewQuiz(scope: requested)
            }
            // 画面を離れている間に制限時間が減り続けないようにする
            .onDisappear { viewModel.suspendTimer() }
            .onAppear {
                // タブを一度も開いていない場合 onChange は発火しないため、初回表示でも拾う
                if let requested = router.consumePendingQuizScope() {
                    viewModel.startNewQuiz(scope: requested)
                } else {
                    viewModel.resumeTimer()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.resumeTimer()
                } else {
                    viewModel.suspendTimer()
                }
            }
        }
    }

    private var startScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("英→日 4択クイズ")
                        .font(.title2).bold()
                    Text("\(QuizViewModel.questionCount)問 / 1問あたり\(QuizViewModel.timeLimitPerQuestion)秒")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // 復習を解き終えて出題対象が無くなったときなど、なぜ始まらなかったのかを伝える
                if let notice = viewModel.notice {
                    Label(notice, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                Button("スタート") { viewModel.startNewQuiz() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.scopeWordCount == 0)

                StudyScopeCard(
                    title: "出題範囲",
                    scope: $scope,
                    matchingCount: viewModel.scopeWordCount,
                    hasUserWords: viewModel.hasUserWords
                )

                if !entitlements.hasFullAccess {
                    lockedNotice
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        // 範囲を変えたら語数の表示をすぐ合わせる
        .onChange(of: scope) { _, newValue in
            StudySettings.studyScope = newValue
            viewModel.refreshScopeCount()
        }
    }

    /// 出題されない理由は「自分で範囲を絞った（設定）」と「まだ解放していない（権利）」の
    /// 2つあり、混ぜると利用者が原因を判断できないので別々に見せる。
    private var lockedNotice: some View {
        Button {
            isShowingPaywall = true
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("2級コア発展語彙はいま出題されません")
                        .font(.caption).bold()
                    Text("解放すると、試験で問われる語が出題対象に加わります")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// タイピング画面と同じ「グループ背景＋白カード」構成に揃えている。
    /// 素のVStackで組んでいたときはコンテンツがナビゲーションバーの下に潜り込み、
    /// 問題番号とタイトル・ツールバーが重なって表示されていた。
    private func quizScreen(question: QuizQuestion) -> some View {
        let hasAnswered = viewModel.selectedChoiceIndex != nil
        let isLastQuestion = viewModel.currentQuestionIndex + 1 >= viewModel.questions.count

        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    progressCard
                    questionCard(question: question)
                }
                .padding()
            }

            if hasAnswered {
                VStack(spacing: 6) {
                    Button(isLastQuestion ? "結果を見る" : "次の問題へ") {
                        viewModel.goToNextQuestion()
                    }
                    .buttonStyle(.borderedProminent)
                    // 片手で持ったまま進められるように、スワイプでも同じ操作ができることを示す
                    Label("上にスワイプでも進めます", systemImage: "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .transition(.opacity)
            }
        }
        .background(Color(.systemGroupedBackground))
        // 正解した選択肢の位置から弾けさせる。画面全体に降らせると、どこで何が起きたのか伝わらない
        .overlayPreferenceValue(ChoiceAnchorKey.self) { anchors in
            GeometryReader { proxy in
                ConfettiView(trigger: celebrationTrigger, origin: confettiOrigin(anchors, in: proxy))
            }
        }
        // 解答後は片手で次へ進めるようにする。解答前はスワイプで飛ばせないようにしておく
        // （読まずに進んでしまうのを防ぐため）。
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard hasAnswered else { return }
                    guard value.translation.height < -50,
                          abs(value.translation.width) < 80 else { return }
                    viewModel.goToNextQuestion()
                }
        )
        .animation(.easeInOut(duration: 0.15), value: hasAnswered)
        // 解答が確定した瞬間に手応えを返す。正解は1回、不正解は3回でタイピングと揃えている。
        .onChange(of: viewModel.selectedChoiceIndex) { _, selected in
            guard let selected, let question = viewModel.currentQuestion else { return }
            if selected == question.correctIndex {
                Haptics.success()
                celebrationTrigger += 1
            } else {
                Haptics.failure()
            }
        }
    }

    /// 正解の選択肢の中心を、紙吹雪の発生源に変換する
    private func confettiOrigin(
        _ anchors: [Int: Anchor<CGRect>],
        in proxy: GeometryProxy
    ) -> UnitPoint {
        guard let question = viewModel.currentQuestion,
              let anchor = anchors[question.correctIndex],
              proxy.size.width > 0, proxy.size.height > 0
        else { return UnitPoint(x: 0.5, y: 0.35) }

        let rect = proxy[anchor]
        return UnitPoint(
            x: rect.midX / proxy.size.width,
            y: rect.midY / proxy.size.height
        )
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("第\(viewModel.currentQuestionIndex + 1)問 / \(viewModel.questions.count)問")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("\(viewModel.remainingSeconds)秒", systemImage: "timer")
                    .font(.subheadline).bold()
                    .foregroundStyle(viewModel.remainingSeconds <= 3 ? .red : .primary)
                    .contentTransition(.numericText())
            }
            ProgressView(value: viewModel.progressFraction)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private func questionCard(question: QuizQuestion) -> some View {
        VStack(spacing: 20) {
            Text(question.word.word)
                .font(.system(size: 38, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            VStack(spacing: 12) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    ChoiceButton(
                        text: choice,
                        state: choiceState(index: index, question: question),
                        action: { viewModel.selectAnswer(index) }
                    )
                    // 紙吹雪を正解の位置から出すために、各選択肢の位置を親へ伝える
                    .anchorPreference(key: ChoiceAnchorKey.self, value: .bounds) { [index: $0] }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private func choiceState(index: Int, question: QuizQuestion) -> ChoiceButton.State {
        guard let selected = viewModel.selectedChoiceIndex else { return .idle }
        if index == question.correctIndex { return .correct }
        if index == selected { return .incorrect }
        return .disabled
    }
}

/// 選択肢の位置を親へ伝えるためのキー。紙吹雪を正解した場所から出すために使う
private struct ChoiceAnchorKey: PreferenceKey {
    static let defaultValue: [Int: Anchor<CGRect>] = [:]

    static func reduce(value: inout [Int: Anchor<CGRect>], nextValue: () -> [Int: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct ChoiceButton: View {
    enum State { case idle, correct, incorrect, disabled }

    let text: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .frame(maxWidth: .infinity)
                .padding()
                .background(background, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(state == .disabled ? .secondary : .primary)
        }
        .disabled(state != .idle)
    }

    private var background: Color {
        switch state {
        case .idle: return Color(.secondarySystemBackground)
        case .correct: return .green.opacity(0.3)
        case .incorrect: return .red.opacity(0.3)
        case .disabled: return Color(.secondarySystemBackground)
        }
    }
}

#Preview {
    QuizView()
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self], inMemory: true)
}
