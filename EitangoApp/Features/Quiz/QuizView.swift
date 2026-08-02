import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TabRouter.self) private var router
    @State private var viewModel = QuizViewModel()
    /// 正解のたびに増やして紙吹雪を発生させる
    @State private var celebrationTrigger = 0

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
                        onRetry: { viewModel.startNewQuiz(scope: viewModel.scope) }
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
        VStack(spacing: 16) {
            Text("英→日 4択クイズ")
                .font(.title2).bold()
            Text("\(QuizViewModel.questionCount)問 / 1問あたり\(QuizViewModel.timeLimitPerQuestion)秒")
                .foregroundStyle(.secondary)
            Button("スタート") { viewModel.startNewQuiz() }
                .buttonStyle(.borderedProminent)
        }
    }

    /// タイピング画面と同じ「グループ背景＋白カード」構成に揃えている。
    /// 素のVStackで組んでいたときはコンテンツがナビゲーションバーの下に潜り込み、
    /// 問題番号とタイトル・ツールバーが重なって表示されていた。
    private func quizScreen(question: QuizQuestion) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    progressCard
                    questionCard(question: question)
                }
                .padding()
            }

            if viewModel.selectedChoiceIndex != nil {
                Button(viewModel.currentQuestionIndex + 1 < viewModel.questions.count ? "次の問題へ" : "結果を見る") {
                    viewModel.goToNextQuestion()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .confetti(trigger: celebrationTrigger)
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
