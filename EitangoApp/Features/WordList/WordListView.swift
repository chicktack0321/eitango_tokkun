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
                }
                ForEach(viewModel.words) { word in
                    NavigationLink(value: word) {
                        WordRow(word: word, status: viewModel.status(for: word))
                    }
                }
            }
            .navigationTitle("単語帳")
            .navigationDestination(for: WordMaster.self) { word in
                WordDetailView(word: word)
            }
            .task { viewModel.configure(context: modelContext) }
            .onChange(of: viewModel.selectedCategory) { _, _ in viewModel.reload() }
            .onChange(of: viewModel.selectedPartOfSpeech) { _, _ in viewModel.reload() }
        }
    }

    private var filterRow: some View {
        HStack {
            Picker("頻出度", selection: $viewModel.selectedCategory) {
                Text("すべて").tag(FrequencyRank?.none)
                ForEach(FrequencyRank.allCases) { rank in
                    Text(rank.displayName).tag(FrequencyRank?.some(rank))
                }
            }
            Picker("品詞", selection: $viewModel.selectedPartOfSpeech) {
                Text("すべて").tag(PartOfSpeech?.none)
                ForEach(PartOfSpeech.allCases) { pos in
                    Text(pos.displayName).tag(PartOfSpeech?.some(pos))
                }
            }
        }
        .pickerStyle(.menu)
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
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch status {
        case .notStudied: return "circle"
        case .memorized: return "checkmark.circle.fill"
        case .needsReview: return "exclamationmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .notStudied: return .secondary
        case .memorized: return .green
        case .needsReview: return .orange
        }
    }
}

#Preview {
    WordListView()
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self], inMemory: true)
}
