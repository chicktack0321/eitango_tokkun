import SwiftUI
import SwiftData

struct WordListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WordListViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterRow
                    statusFilterRow
                }
                if viewModel.words.isEmpty {
                    ContentUnavailableView(
                        "該当する単語がありません",
                        systemImage: "magnifyingglass",
                        description: Text("絞り込み条件や検索語を変えてみてください")
                    )
                } else {
                    ForEach(viewModel.words) { word in
                        NavigationLink(value: word) {
                            WordRow(word: word, status: viewModel.status(for: word))
                        }
                    }
                }
            }
            .navigationTitle("単語帳")
            .searchable(text: $viewModel.filter.keyword, prompt: "英単語・日本語訳で検索")
            .navigationDestination(for: WordMaster.self) { word in
                WordDetailView(word: word)
            }
            .task { viewModel.configure(context: modelContext) }
            .onChange(of: viewModel.filter) { _, _ in viewModel.reload() }
        }
    }

    /// 「要復習だけ見る」は使用頻度が高いので、メニューに畳まず1タップで切り替えられるようにする
    private var statusFilterRow: some View {
        Picker("ステータス", selection: $viewModel.filter.status) {
            Text("すべて").tag(LearningStatus?.none)
            ForEach(LearningStatus.allCases) { status in
                Text(status.displayName).tag(LearningStatus?.some(status))
            }
        }
        .pickerStyle(.segmented)
    }

    // Picker(.menu) はラベル+選択値を1行で表示しようとするため、幅が狭い端末ではラベルが折り返して
    // 崩れることがあった。Menuを直接使い `.lineLimit(1)` で明示的に1行固定にする。
    private var filterRow: some View {
        HStack {
            filterMenu(
                title: "頻出度",
                selectedLabel: viewModel.filter.category?.displayName ?? "すべて"
            ) {
                Button("すべて") { viewModel.filter.category = nil }
                ForEach(FrequencyRank.allCases) { rank in
                    Button(rank.displayName) { viewModel.filter.category = rank }
                }
            }
            Spacer(minLength: 12)
            filterMenu(
                title: "品詞",
                selectedLabel: viewModel.filter.partOfSpeech?.displayName ?? "すべて"
            ) {
                Button("すべて") { viewModel.filter.partOfSpeech = nil }
                ForEach(PartOfSpeech.allCases) { pos in
                    Button(pos.displayName) { viewModel.filter.partOfSpeech = pos }
                }
            }
        }
    }

    private func filterMenu<Content: View>(
        title: String,
        selectedLabel: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(title).foregroundStyle(.primary)
                Text(selectedLabel).foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .lineLimit(1)
            .fixedSize()
        }
    }
}

private struct WordRow: View {
    let word: WordMaster
    let status: LearningStatus

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(word.word).font(.headline)
                Text(word.meaning).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(word.category.rawValue)
                .font(.caption).bold()
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
            statusIcon
        }
    }

    private var statusIcon: some View {
        Image(systemName: status.symbolName)
            .foregroundStyle(status.tint)
            .accessibilityLabel(status.displayName)
    }
}

#Preview {
    WordListView()
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self], inMemory: true)
}
