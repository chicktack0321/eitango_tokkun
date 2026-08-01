import SwiftUI

/// 1セット分の結果。Viewが `@Model` を直接触らずに済むよう値型に詰め替えている。
struct QuizResultSummary {
    struct MissedWord: Identifiable {
        let id: String
        let word: String
        let meaning: String
    }

    let scope: QuizScope
    let correctCount: Int
    let totalCount: Int
    /// 時間切れで落とした数。選び間違いと分けて出す（対策が「速く解く」か「覚え直す」かで変わるため）
    let timeoutCount: Int
    let newlyMemorizedCount: Int
    let elapsedSeconds: Int
    let missedWords: [MissedWord]

    var accuracy: Double {
        totalCount == 0 ? 0 : Double(correctCount) / Double(totalCount)
    }

    var accuracyPercent: Int { Int((accuracy * 100).rounded()) }

    /// 選択を誤った数（時間切れを除く）
    var wrongChoiceCount: Int { max(0, (totalCount - correctCount) - timeoutCount) }

    var averageSecondsPerQuestion: Double {
        totalCount == 0 ? 0 : Double(elapsedSeconds) / Double(totalCount)
    }
}

struct QuizResultView: View {
    let summary: QuizResultSummary
    let onRetry: () -> Void

    private var grade: (label: String, color: Color) {
        switch summary.accuracyPercent {
        case 90...: return ("S", .yellow)
        case 75..<90: return ("A", .blue)
        case 60..<75: return ("B", .green)
        case 40..<60: return ("C", .primary)
        default: return ("D", .secondary)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headline
                statsCard
                if summary.newlyMemorizedCount > 0 {
                    memorizedCard
                }
                if !summary.missedWords.isEmpty {
                    missedCard
                }
                Button("もう一度挑戦する", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(summary.scope == .reviewOnly ? "復習おつかれさまでした" : "結果")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(grade.label)
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(grade.color)
            Text("\(summary.correctCount) / \(summary.totalCount) 問正解（\(summary.accuracyPercent)%）")
                .font(.title3).bold()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var statsCard: some View {
        DashboardCard(title: "内訳") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatTile(value: "\(summary.correctCount) 問", label: "正解", tint: .green)
                StatTile(value: "\(summary.wrongChoiceCount) 問", label: "選択ミス", tint: .red)
                StatTile(
                    value: "\(summary.timeoutCount) 問",
                    label: "時間切れ",
                    tint: .orange,
                    infoMessage: "制限時間内に選べなかった問題です。意味は分かっていても思い出すのに時間がかかっている可能性があります。"
                )
                StatTile(
                    value: String(format: "%.1f 秒", summary.averageSecondsPerQuestion),
                    label: "1問あたり",
                    tint: .blue
                )
            }
        }
    }

    private var memorizedCard: some View {
        DashboardCard(title: "習熟度が上がりました") {
            HStack(spacing: 8) {
                Image(systemName: LearningStatus.memorized.symbolName)
                    .foregroundStyle(LearningStatus.memorized.tint)
                Text("\(summary.newlyMemorizedCount)語が「覚えた」に到達しました")
                    .font(.subheadline)
                Spacer()
            }
        }
    }

    /// 間違えた語をその場で見返せるようにする。結果が数字だけだと、
    /// 何を復習すればよいかを別画面で探し直すことになるため。
    private var missedCard: some View {
        DashboardCard(title: "間違えた単語（\(summary.missedWords.count)語）") {
            VStack(spacing: 0) {
                ForEach(Array(summary.missedWords.enumerated()), id: \.element.id) { index, word in
                    HStack(alignment: .firstTextBaseline) {
                        Text(word.word)
                            .font(.subheadline).bold()
                        Spacer()
                        Text(word.meaning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 8)
                    if index < summary.missedWords.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

#Preview {
    QuizResultView(
        summary: QuizResultSummary(
            scope: .mixed,
            correctCount: 12,
            totalCount: 15,
            timeoutCount: 1,
            newlyMemorizedCount: 3,
            elapsedSeconds: 78,
            missedWords: [
                .init(id: "1", word: "necessary", meaning: "必要な"),
                .init(id: "2", word: "significant", meaning: "重要な、著しい")
            ]
        ),
        onRetry: {}
    )
}
