import Foundation
import SwiftData

/// ユーザーが追加した単語の読み書き。
///
/// 原本は `UserWord`、表示・出題用の複製が `WordMaster` という二段構えになっている。
/// 追加・編集・削除のたびに両方を揃えるのがこの型の責務で、他の層は
/// これまで通り `WordMaster` だけを見ればよい。
@MainActor
struct UserWordRepository {
    let context: ModelContext

    enum SaveError: LocalizedError, Equatable {
        case emptyWord
        case emptyMeaning
        case duplicate(String)

        var errorDescription: String? {
            switch self {
            case .emptyWord: return "英単語を入力してください。"
            case .emptyMeaning: return "日本語の意味を入力してください。"
            case .duplicate(let word): return "「\(word)」は単語帳にすでにあります。"
            }
        }
    }

    func all() -> [UserWord] {
        let descriptor = FetchDescriptor<UserWord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func userWord(for wordId: String) -> UserWord? {
        let descriptor = FetchDescriptor<UserWord>(predicate: #Predicate { $0.wordId == wordId })
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func add(
        word: String,
        meaning: String,
        example: String,
        category: FrequencyRank,
        partOfSpeech: PartOfSpeech
    ) throws -> UserWord {
        let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { throw SaveError.emptyWord }
        guard !meaning.isEmpty else { throw SaveError.emptyMeaning }
        guard !spellingExists(word, excluding: nil) else { throw SaveError.duplicate(word) }

        let userWord = UserWord(
            word: word,
            meaning: meaning,
            example: example.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            partOfSpeech: partOfSpeech
        )
        context.insert(userWord)
        mirror(userWord)
        try context.save()
        return userWord
    }

    func update(
        _ userWord: UserWord,
        word: String,
        meaning: String,
        example: String,
        category: FrequencyRank,
        partOfSpeech: PartOfSpeech
    ) throws {
        let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { throw SaveError.emptyWord }
        guard !meaning.isEmpty else { throw SaveError.emptyMeaning }
        guard !spellingExists(word, excluding: userWord.wordId) else { throw SaveError.duplicate(word) }

        userWord.word = word
        userWord.meaning = meaning
        userWord.example = example.trimmingCharacters(in: .whitespacesAndNewlines)
        userWord.category = category
        userWord.partOfSpeech = partOfSpeech
        userWord.updatedAt = .now
        mirror(userWord)
        try context.save()
    }

    /// 単語と、その学習履歴をまとめて削除する。
    /// 自分で消した単語の履歴を残しても参照先が無く、集計にだけ残って邪魔になる。
    func delete(_ userWord: UserWord) {
        let wordId = userWord.wordId
        if let master = master(for: wordId) {
            context.delete(master)
        }
        let progressDescriptor = FetchDescriptor<UserProgress>(predicate: #Predicate { $0.wordId == wordId })
        for progress in (try? context.fetch(progressDescriptor)) ?? [] {
            context.delete(progress)
        }
        context.delete(userWord)
        try? context.save()
    }

    /// `UserWord` の内容を `WordMaster` 側へ反映する。
    /// 起動時に呼べば、ストアを作り直したあとや、同梱データの改訂で
    /// マスターが入れ替わったあとでも、ユーザーの単語が単語帳に戻る。
    func syncToMaster() {
        let words = all()
        for word in words {
            mirror(word)
        }

        // 原本が消えている複製（過去の不整合など）は残さない
        let userMasters = (try? context.fetch(
            FetchDescriptor<WordMaster>(predicate: #Predicate { $0.sourceRaw == "user" })
        )) ?? []
        let liveIds = Set(words.map(\.wordId))
        for master in userMasters where !liveIds.contains(master.wordId) {
            context.delete(master)
        }

        try? context.save()
    }

    // MARK: - 内部

    private func master(for wordId: String) -> WordMaster? {
        let descriptor = FetchDescriptor<WordMaster>(predicate: #Predicate { $0.wordId == wordId })
        return try? context.fetch(descriptor).first
    }

    /// 同じ綴りの語がすでに単語帳にあるか（大文字小文字は区別しない）
    private func spellingExists(_ word: String, excluding wordId: String?) -> Bool {
        let target = word.lowercased()
        let all = (try? context.fetch(FetchDescriptor<WordMaster>())) ?? []
        return all.contains { $0.wordId != wordId && $0.word.lowercased() == target }
    }

    private func mirror(_ userWord: UserWord) {
        if let existing = master(for: userWord.wordId) {
            existing.word = userWord.word
            existing.meaning = userWord.meaning
            existing.example = userWord.example
            existing.category = userWord.category
            existing.partOfSpeech = userWord.partOfSpeech
            existing.updatedAt = userWord.updatedAt
            existing.source = .user
        } else {
            context.insert(
                WordMaster(
                    wordId: userWord.wordId,
                    word: userWord.word,
                    meaning: userWord.meaning,
                    example: userWord.example,
                    // 過去問での出題回数は自作の語には無い。0にして詳細画面でも表示を出し分ける。
                    frequencyCount: 0,
                    category: userWord.category,
                    partOfSpeech: userWord.partOfSpeech,
                    updatedAt: userWord.updatedAt,
                    source: .user
                )
            )
        }

        // 出題対象にするには進捗行が要る（同梱データはseedが作っている）
        if userWord.wordId.isEmpty == false, progress(for: userWord.wordId) == nil {
            context.insert(UserProgress(wordId: userWord.wordId))
        }
    }

    private func progress(for wordId: String) -> UserProgress? {
        let descriptor = FetchDescriptor<UserProgress>(predicate: #Predicate { $0.wordId == wordId })
        return try? context.fetch(descriptor).first
    }
}
