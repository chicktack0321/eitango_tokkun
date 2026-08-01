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
        case 20..<30: return ("A", .cyan)
        case 12..<20: return ("B", .green)
        case 6..<12: return ("C", .white)
        default: return ("D", .gray)
        }
    }

    private var accuracyPercent: Int {
        Int((accuracy * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("RESULT").font(.caption).foregroundStyle(.gray)
                Text("タイム アップ！").font(.title).bold()
            }

            Text(grade.label)
                .font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(grade.color)

            VStack(spacing: 2) {
                Text("FINAL SCORE").font(.caption).foregroundStyle(.gray)
                Text("\(score)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statTile(label: "正解単語数", value: "\(correctWordCount) 語", color: .green)
                statTile(label: "ミス回数", value: "\(missCount) 回", color: .red)
                statTile(label: "最大コンボ", value: "\(maxCombo) x", color: .orange)
                statTile(label: "正確率", value: "\(accuracyPercent) %", color: .cyan)
            }
            .frame(maxWidth: 360)

            Button("もう一度挑戦する", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .foregroundStyle(.white)
    }

    private func statTile(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.gray)
            Text(value).font(.title3).bold().foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TypingResultView(score: 1280, correctWordCount: 14, missCount: 3, maxCombo: 9, accuracy: 0.86, onRetry: {})
}
