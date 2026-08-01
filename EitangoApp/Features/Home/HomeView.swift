import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TabRouter.self) private var router
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    todayCard
                    masteryCard
                    quickActionsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ホーム")
            .task { viewModel.configure(context: modelContext) }
            .onChange(of: router.selectedTab) { _, newValue in
                if newValue == .home { viewModel.reload() }
            }
        }
    }

    private var todayCard: some View {
        DashboardCard(title: "今日の学習") {
            HStack(spacing: 12) {
                StatTile(
                    value: "\(viewModel.todayStudiedCount)問",
                    label: "解答した単語数",
                    tint: .blue
                )
                StatTile(
                    value: percentString(viewModel.todayAccuracy),
                    label: "今日の正答率",
                    tint: .green
                )
            }
        }
    }

    private var masteryCard: some View {
        DashboardCard(title: "習熟度（全\(viewModel.totalWordCount)語）") {
            VStack(alignment: .leading, spacing: 10) {
                MasteryBar(
                    memorized: viewModel.memorizedCount,
                    needsReview: viewModel.needsReviewCount,
                    notStudied: viewModel.notStudiedCount
                )
                HStack(spacing: 16) {
                    LegendDot(color: .green, label: "覚えた \(viewModel.memorizedCount)")
                    LegendDot(color: .orange, label: "要復習 \(viewModel.needsReviewCount)")
                    LegendDot(color: .secondary, label: "未学習 \(viewModel.notStudiedCount)")
                }
                .font(.caption)

                Divider()

                HStack {
                    Text("累計正答率")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

/// 覚えた/要復習/未学習の内訳を表す横積み上げバー
private struct MasteryBar: View {
    let memorized: Int
    let needsReview: Int
    let notStudied: Int

    private var total: Int { memorized + needsReview + notStudied }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                segment(count: memorized, color: .green, width: proxy.size.width)
                segment(count: needsReview, color: .orange, width: proxy.size.width)
                segment(count: notStudied, color: Color(.systemGray4), width: proxy.size.width)
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
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self], inMemory: true)
}
