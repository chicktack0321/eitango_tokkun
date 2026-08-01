import SwiftUI
import SwiftData
import Charts

/// 学習の推移を見せる画面。`StudyLog` に日次データは貯まっていたが当日分しか使っていなかったため、
/// 「続けられている実感」を返す場所として用意した。
struct StudyHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = StudyHistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                rangePicker
                streakCard
                chartCard
                summaryCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("学習の記録")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.configure(context: modelContext) }
    }

    private var rangePicker: some View {
        Picker("期間", selection: $viewModel.selectedPeriod) {
            ForEach(StudyHistoryViewModel.Period.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var streakCard: some View {
        DashboardCard(title: "継続日数") {
            HStack(spacing: 12) {
                StatTile(value: "\(viewModel.streak)日", label: "連続学習", tint: .orange)
                StatTile(
                    value: "\(viewModel.studiedDayCount)日",
                    label: "この期間に学習した日数",
                    tint: .blue
                )
            }
        }
    }

    private var chartCard: some View {
        DashboardCard(title: "解答した単語数") {
            if viewModel.hasAnyRecord {
                Chart(viewModel.series) { day in
                    BarMark(
                        x: .value("日", day.date, unit: .day),
                        y: .value("解答数", day.studiedWordCount)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
            } else {
                emptyState
            }
        }
    }

    /// 30日表示で日付ラベルを毎日出すと潰れるので、期間に応じて間引く
    private var xAxisStride: Int {
        viewModel.selectedPeriod == .month ? 7 : 3
    }

    private var summaryCard: some View {
        DashboardCard(title: "この期間の合計") {
            HStack(spacing: 12) {
                StatTile(value: "\(viewModel.totalAttempts)問", label: "解答数", tint: .indigo)
                StatTile(
                    value: "\(Int((viewModel.overallAccuracy * 100).rounded()))%",
                    label: "正答率",
                    tint: .green
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("まだ学習の記録がありません")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("クイズやタイピングを解くとここに推移が表示されます")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}

#Preview {
    NavigationStack {
        StudyHistoryView()
    }
    .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self], inMemory: true)
}
