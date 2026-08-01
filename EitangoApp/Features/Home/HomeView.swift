import SwiftUI
import SwiftData
import Charts

/// ホームから push する画面。増えても `navigationDestination` を1か所にまとめられるよう列挙にしている。
enum HomeDestination: Hashable {
    case history
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TabRouter.self) private var router
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    titleHeader
                    todayCard
                    historyCard
                    masteryCard
                    quickActionsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ホーム")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .history: StudyHistoryView()
                }
            }
            .task { viewModel.configure(context: modelContext) }
            .onChange(of: router.selectedTab) { _, newValue in
                if newValue == .home { viewModel.reload() }
            }
        }
    }

    /// ナビゲーションバーの「ホーム」に代えて、アプリ名とロゴを出す
    private var titleHeader: some View {
        HStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("英単語特訓")
                    .font(.title2).bold()
                Text("英検2級")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var todayCard: some View {
        DashboardCard(title: "今日の学習") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    StatTile(
                        value: "\(viewModel.todayStudiedCount)問",
                        label: "解答した単語数",
                        tint: .blue,
                        infoMessage: MetricExplanations.todayStudied
                    )
                    StatTile(
                        value: percentString(viewModel.todayAccuracy),
                        label: "今日の正答率",
                        tint: .green,
                        infoMessage: MetricExplanations.todayAccuracy
                    )
                }

                // 復習期限が来た語がある日は、まずそこから手を付けてもらう。
                // 出題対象を渡して、押した通りに復習だけが始まるようにしている。
                if viewModel.dueCount > 0 {
                    Button {
                        router.startQuiz(scope: .reviewOnly)
                    } label: {
                        HStack {
                            Label("復習する単語が\(viewModel.dueCount)語あります", systemImage: "arrow.clockwise")
                                .font(.subheadline)
                            InfoButton(title: "復習する単語", message: MetricExplanations.dueForReview)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .foregroundStyle(.orange)
                        .padding(12)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 直近1週間の推移をミニグラフで見せ、詳しい記録は専用画面へ送る
    private var historyCard: some View {
        NavigationLink(value: HomeDestination.history) {
            DashboardCard(title: "学習の記録") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("\(viewModel.streak)日連続", systemImage: "flame.fill")
                            .font(.subheadline).bold()
                            .foregroundStyle(.orange)
                        InfoButton(title: "連続日数", message: MetricExplanations.streak)
                        Spacer()
                        Text("詳しく見る")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.weeklySeries.contains(where: \.didStudy) {
                        Chart(viewModel.weeklySeries) { day in
                            BarMark(
                                x: .value("日", day.date, unit: .day),
                                y: .value("解答数", day.studiedWordCount)
                            )
                            .foregroundStyle(Color.blue.gradient)
                            .cornerRadius(2)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 60)
                    } else {
                        Text("今週はまだ記録がありません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        // カード内の文字列が連結されてラベルになるため、UIテストからは識別子で引く
        .accessibilityIdentifier("historyCardLink")
    }

    private var masteryCard: some View {
        DashboardCard(
            title: "習熟度（全\(viewModel.totalWordCount)語）",
            infoMessage: MetricExplanations.mastery
        ) {
            VStack(alignment: .leading, spacing: 10) {
                MasteryBar(counts: viewModel.summary.statusCounts)

                // 段階が4つあるので凡例は2列に折り返す
                LazyVGrid(
                    columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(LearningStatus.allCases) { status in
                        LegendDot(
                            color: status.barColor,
                            label: "\(status.displayName) \(viewModel.summary.count(of: status))"
                        )
                    }
                }
                .font(.caption)

                Divider()

                HStack(spacing: 4) {
                    Text("累計正答率")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    InfoButton(title: "累計正答率", message: MetricExplanations.overallAccuracy)
                    Spacer()
                    Text(percentString(viewModel.overallAccuracy))
                        .font(.subheadline).bold()
                }
            }
        }
    }

    private var quickActionsCard: some View {
        DashboardCard(title: "クイックアクション") {
            VStack(spacing: 10) {
                Button {
                    router.selectedTab = .quiz
                } label: {
                    Label("4択クイズを始める", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    router.selectedTab = .typing
                } label: {
                    Label("タイピングテストを始める", systemImage: "keyboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    router.selectedTab = .listening
                } label: {
                    Label("聞き流しを始める", systemImage: "headphones")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    router.selectedTab = .wordList
                } label: {
                    Label("単語帳を見る", systemImage: "text.book.closed")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

// MARK: - 共通パーツ
// DashboardCard / StatTile は Common/CardComponents.swift に共通化（TypingViewとも共有）

/// 習熟段階の内訳を表す横積み上げバー。
/// 覚えた側から並べ、学習が進むほど左から緑が伸びていくように見せる。
private struct MasteryBar: View {
    let counts: [LearningStatus: Int]

    /// 表示順。習得済みを左端に置く
    private static let order: [LearningStatus] = [.memorized, .learning, .needsReview, .notStudied]

    private var total: Int { counts.values.reduce(0, +) }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(Self.order, id: \.self) { status in
                    segment(count: counts[status] ?? 0, color: status.barColor, width: proxy.size.width)
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
    }

    private func segment(count: Int, color: Color, width: CGFloat) -> some View {
        let fraction = total == 0 ? 0 : CGFloat(count) / CGFloat(total)
        return color.frame(width: width * fraction)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    HomeView()
        .environment(TabRouter())
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self], inMemory: true)
}
