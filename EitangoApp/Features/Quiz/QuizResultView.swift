import SwiftUI

struct QuizResultView: View {
    let correctCount: Int
    let totalCount: Int
    let onRetry: () -> Void

    private var accuracyPercent: Int {
        totalCount == 0 ? 0 : Int((Double(correctCount) / Double(totalCount) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("結果")
                .font(.title).bold()

            Text("\(correctCount) / \(totalCount) 問正解")
                .font(.title2)

            Text("正答率 \(accuracyPercent)%")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button("もう一度挑戦する", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    QuizResultView(correctCount: 12, totalCount: 15, onRetry: {})
}
