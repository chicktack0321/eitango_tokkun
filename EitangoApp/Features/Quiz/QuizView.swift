import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
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
            .task { viewModel.configure(context: modelContext) }
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

    private func quizScreen(question: QuizQuestion) -> some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.progressFraction)
                .padding(.horizontal)

            HStack {
                Text("第\(viewModel.currentQuestionIndex + 1)問 / \(viewModel.questions.count)問")
                Spacer()
                Label("\(viewModel.remainingSeconds)秒", systemImage: "timer")
                    .foregroundStyle(viewModel.remainingSeconds <= 3 ? .red : .primary)
            }
            .padding(.horizontal)

            Text(question.word.word)
                .font(.system(size: 40, weight: .bold))
                .padding(.top, 24)

            VStack(spacing: 12) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    ChoiceButton(
                        text: choice,
                        state: choiceState(index: index, question: question),
                        action: { viewModel.selectAnswer(index) }
                    )
                }
            }
            .padding(.horizontal)

            Spacer()

            if viewModel.selectedChoiceIndex != nil {
                Button(viewModel.currentQuestionIndex + 1 < viewModel.questions.count ? "次の問題へ" : "結果を見る") {
                    viewModel.goToNextQuestion()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
        }
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
