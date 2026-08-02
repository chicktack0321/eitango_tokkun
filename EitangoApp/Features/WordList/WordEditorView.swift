import SwiftUI
import SwiftData

/// 自分の単語を追加・編集する画面。
///
/// 保存の直前に綴りを確認する。誤りは警告にとどめ、そのまま登録する道も残す
/// （固有名詞や辞書に載っていない語もあるため）。
struct WordEditorView: View {
    /// 編集対象。nil なら新規追加。
    var editing: UserWord?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var word = ""
    @State private var meaning = ""
    @State private var example = ""
    @State private var category: FrequencyRank = .c
    @State private var partOfSpeech: PartOfSpeech = .noun

    @State private var spellResult: SpellChecker.Result?
    @State private var saveError: String?
    /// 綴りの警告を承知のうえで登録するか。候補を選び直したら解除する。
    @State private var acceptsSpelling = false

    @FocusState private var wordFieldFocused: Bool

    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("英単語", text: $word)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .focused($wordFieldFocused)
                        .onChange(of: word) { _, _ in
                            // 打ち直したら前回の判定は無効
                            spellResult = nil
                            acceptsSpelling = false
                            saveError = nil
                        }
                        .onSubmit(runSpellCheck)
                    TextField("日本語の意味", text: $meaning)
                } header: {
                    Text("単語")
                } footer: {
                    Text("追加した単語は単語帳・クイズ・タイピング・聞き流しにそのまま出てきます。")
                }

                if let spellResult {
                    spellSection(for: spellResult)
                }

                Section("例文（任意）") {
                    TextField("例文", text: $example, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("分類") {
                    Picker("頻出度", selection: $category) {
                        ForEach(FrequencyRank.allCases) { rank in
                            Text(rank.displayName).tag(rank)
                        }
                    }
                    Picker("品詞", selection: $partOfSpeech) {
                        ForEach(PartOfSpeech.allCases) { pos in
                            Text(pos.displayName).tag(pos)
                        }
                    }
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(isEditing ? "単語を編集" : "単語を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "保存" : "追加") { attemptSave() }
                        .bold()
                }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    // MARK: - 綴りの確認

    @ViewBuilder
    private func spellSection(for result: SpellChecker.Result) -> some View {
        switch result {
        case .ok:
            Section {
                Label("辞書で確認できました", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }
        case .empty:
            EmptyView()
        case .invalidCharacters:
            Section {
                Label("英字で入力してください（日本語や記号は使えません）", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
            }
        case .misspelled(let suggestions):
            Section {
                Label("辞書に見つかりませんでした", systemImage: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)

                if suggestions.isEmpty {
                    Text("近い綴りの候補はありません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            word = suggestion
                            spellResult = SpellChecker.check(suggestion)
                        } label: {
                            HStack {
                                Text(suggestion)
                                Spacer()
                                Text("この綴りにする")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button("このまま追加する") {
                    acceptsSpelling = true
                    attemptSave()
                }
                .font(.subheadline)
            } header: {
                Text("綴りの確認")
            } footer: {
                Text("固有名詞や辞書に無い語はそのまま追加できます。")
            }
        }
    }

    private func runSpellCheck() {
        spellResult = SpellChecker.check(word)
    }

    // MARK: - 保存

    private func loadIfEditing() {
        guard let editing else {
            wordFieldFocused = true
            return
        }
        // 画面が再表示されたときに入力中の内容を巻き戻さない
        guard word.isEmpty else { return }
        word = editing.word
        meaning = editing.meaning
        example = editing.example
        category = editing.category
        partOfSpeech = editing.partOfSpeech
    }

    private func attemptSave() {
        saveError = nil

        let result = SpellChecker.check(word)
        spellResult = result
        // 未入力と英字以外の混入だけは直してもらう。綴り違いは警告にとどめる。
        if result == .empty {
            saveError = UserWordRepository.SaveError.emptyWord.errorDescription
            return
        }
        if result.isBlocking { return }
        if case .misspelled = result, !acceptsSpelling { return }

        let repository = UserWordRepository(context: modelContext)
        do {
            if let editing {
                try repository.update(
                    editing,
                    word: word,
                    meaning: meaning,
                    example: example,
                    category: category,
                    partOfSpeech: partOfSpeech
                )
            } else {
                try repository.add(
                    word: word,
                    meaning: meaning,
                    example: example,
                    category: category,
                    partOfSpeech: partOfSpeech
                )
            }
            dismiss()
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription ?? "保存できませんでした。"
        }
    }
}

#Preview {
    WordEditorView()
        .modelContainer(for: [WordMaster.self, UserProgress.self, StudyLog.self, TypingScore.self, UserWord.self], inMemory: true)
}
