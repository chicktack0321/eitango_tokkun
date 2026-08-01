import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = QuizViewModel()

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
                        correctCount: viewModel.correctAnswerCount,
                        totalCount: viewModel.questions.count,
                        onRetry: { viewModel.startNewQuiz() }
                    )
                }
            }
            .navigationTitle("4択クイズ")
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
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self], inMemory: true)
}
