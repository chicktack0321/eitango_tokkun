import SwiftUI

struct TypingResultView: View {
    let score: Int
    let correctWordCount: Int
    let missCount: Int
    let maxCombo: Int
    let accuracy: Double
    let onRetry: () -> Void

    private var grade: (label: String, color: Color) {
        switch correctWordCount {
        case 30...: return ("S", .yellow)
        case 20..<30: return ("A", .blue)
        case 12..<20: return ("B", .green)
        case 6..<12: return ("C", .primary)
        default: return ("D", .secondary)
        }
    }

    private var accuracyPercent: Int {
        Int((accuracy * 100).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("結果")
                    .font(.title).bold()

                Text(grade.label)
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(grade.color)

                VStack(spacing: 2) {
                    Text("SCORE")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.blue)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(value: "\(correctWordCount) 語", label: "正解単語数", tint: .green)
                    StatTile(value: "\(missCount) 回", label: "ミス回数", tint: .red)
                    StatTile(value: "\(maxCombo) x", label: "最大コンボ", tint: .orange)
                    StatTile(value: "\(accuracyPercent) %", label: "正確率", tint: .blue)
                }
                .frame(maxWidth: 360)

                Button("もう一度挑戦する", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

#Preview {
    TypingResultView(score: 1280, correctWordCount: 14, missCount: 3, maxCombo: 9, accuracy: 0.86, onRetry: {})
}
