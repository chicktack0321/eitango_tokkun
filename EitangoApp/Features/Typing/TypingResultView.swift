import SwiftUI

/// 自己ベスト一覧。開始画面と結果画面の両方で使う。
struct TypingBestScoreCard: View {
    let scores: [TypingScore]
    /// 今回の記録が入った順位（1始まり）。該当行を強調する。
    let highlightedIndex: Int?

    var body: some View {
        DashboardCard(title: "自己ベスト") {
            VStack(spacing: 0) {
                ForEach(Array(scores.enumerated()), id: \.element.persistentModelID) { index, score in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption).bold()
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        Text("\(score.score)")
                            .font(.subheadline).bold()
                            .foregroundStyle(highlightedIndex == index + 1 ? Color.orange : .primary)

                        if score.isHiddenMode {
                            Text("かくれんぼ")
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15), in: Capsule())
                                .foregroundStyle(.purple)
                        }

                        Spacer()

                        Text("\(score.correctWordCount)語")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(score.playedAt.formatted(.dateTime.month(.defaultDigits).day()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 7)

                    if index < scores.count - 1 { Divider() }
                }
            }
        }
    }
}

struct TypingResultView: View {
    let score: Int
    let correctWordCount: Int
    let missCount: Int
    let maxCombo: Int
    let accuracy: Double
    let mode: TypingViewModel.Mode
    let achievement: TypingScoreRepository.Achievement
    let bestScores: [TypingScore]
    let onRetry: () -> Void

    /// 自己ベスト更新時に一度だけ紙吹雪を出す
    @State private var celebrationTrigger = 0

    private var grade: (label: String, color: Color) {
        switch correctWordCount {
        case 30...: return ("S", .yellow)
        case 20..<30: return ("A", .blue)
        case 12..<20: return ("B", .green)
        case 6..<12: return ("C", .primary)
        default: return ("D", .secondary)
        }
    }

    private var accuracyPercent: Int { Int((accuracy * 100).rounded()) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if achievement.isNewBest {
                    newBestBanner
                } else if let rank = achievement.rank, achievement.enteredRanking {
                    rankBanner(rank: rank)
                }

                headline
                statsCard

                if !bestScores.isEmpty {
                    TypingBestScoreCard(
                        scores: bestScores,
                        highlightedIndex: achievement.enteredRanking ? achievement.rank : nil
                    )
                }

                Button("もう一度挑戦する", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .confetti(trigger: celebrationTrigger)
        .onAppear {
            // 自己ベストのときだけ、振動と紙吹雪で通常のクリアと差をつける
            if achievement.isNewBest {
                Haptics.celebrate()
                celebrationTrigger += 1
            }
        }
    }

    private var newBestBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("自己ベスト更新！")
                    .font(.subheadline).bold()
                Text("これまでの最高得点を超えました")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private func rankBanner(rank: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .foregroundStyle(.orange)
            Text("自己ベスト\(rank)位に入りました")
                .font(.subheadline).bold()
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var headline: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("RESULT").font(.caption).foregroundStyle(.secondary)
                if mode == .hidden {
                    Text("かくれんぼ")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15), in: Capsule())
                        .foregroundStyle(.purple)
                }
            }
            Text(grade.label)
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(grade.color)
            Text("\(score)")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.blue)
            Text("SCORE").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var statsCard: some View {
        DashboardCard(title: "内訳") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatTile(value: "\(correctWordCount) 語", label: "正解単語数", tint: .green)
                StatTile(value: "\(missCount) 回", label: "ミス回数", tint: .red)
                StatTile(value: "\(maxCombo) x", label: "最大コンボ", tint: .orange)
                StatTile(
                    value: "\(accuracyPercent) %",
                    label: "正確率",
                    tint: .blue,
                    infoMessage: "打鍵のうち正しかった割合です。正しく打った文字数 ÷（正しく打った文字数＋ミス回数）で求めています。"
                )
            }
        }
    }
}
