import SwiftUI
import SwiftData

struct WordListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WordListViewModel()
    @State private var isAddingWord = false
    @State private var entitlements = Entitlements.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    tierFilterRow
                    filterRow
                    statusFilterRow
                } header: {
                    Text("\(viewModel.words.count)語")
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
                            WordRow(
                                word: word,
                                status: viewModel.status(for: word),
                                // 閲覧は常にできる。鍵は「出題対象から外れている」ことを示すだけ
                                isLockedForStudy: !entitlements.availableTiers.contains(word.tier)
                                    && word.source != .user
                            )
                        }
                        // 単語の行であることをUIテストから確実に指せるようにする。
                        // 並び順や絞り込み行の数で位置が変わるため、位置指定では取り違える。
                        .accessibilityIdentifier("wordRow")
                    }
                }
            }
            .navigationTitle("単語帳")
            .searchable(text: $viewModel.filter.keyword, prompt: "英単語・日本語訳で検索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingWord = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("単語を追加")
                    .accessibilityIdentifier("addWordButton")
                }
            }
            .navigationDestination(for: WordMaster.self) { word in
                WordDetailView(word: word)
            }
            // 追加・編集・削除のあとは一覧を作り直す（並びと件数が変わるため）
            .sheet(isPresented: $isAddingWord, onDismiss: { viewModel.reload() }) {
                WordEditorView()
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

    /// 語彙階層と分野。5,000語規模では「どの層を今やるか」を決めるのが最初の操作になるので、
    /// 頻出度・品詞より上に置く。
    private var tierFilterRow: some View {
        HStack {
            filterMenu(
                title: "階層",
                selectedLabel: viewModel.filter.tier?.displayName ?? "すべて"
            ) {
                Button("すべて") { viewModel.filter.tier = nil }
                ForEach(VocabularyTier.allCases) { tier in
                    Button(tier.displayName) { viewModel.filter.tier = tier }
                }
            }
            Spacer(minLength: 12)
            filterMenu(
                title: "分野",
                selectedLabel: viewModel.filter.domain?.displayName ?? "すべて"
            ) {
                Button("すべて") { viewModel.filter.domain = nil }
                ForEach(VocabularyDomain.allCases) { domain in
                    Button(domain.displayName) { viewModel.filter.domain = domain }
                }
            }
        }
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
    /// 出題対象から外れている語。意味は読めるので伏せ字にはしない
    var isLockedForStudy: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(word.word).font(.headline)
                Text(word.meaning).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if isLockedForStudy {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("出題対象外")
            }
            // 自分で追加した語は、同梱の頻出度ランクと意味が違うので見分けられるようにする
            if word.source == .user {
                Image(systemName: "person.crop.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .accessibilityLabel("自分で追加した単語")
            }
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
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self, UserWord.self], inMemory: true)
}
