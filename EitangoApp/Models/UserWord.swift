import Foundation
import SwiftData

/// ユーザーが自分で追加した単語。`UserProgress` と同じく、アプリ更新を跨いで必ず保持される
/// Read-Write テーブル。
///
/// 表示や出題は `WordMaster` を通して行うため、追加・編集のたびに同じ内容を
/// `WordMaster` へ複製する（`UserWordRepository.syncToMaster`）。
/// `WordMaster` にだけ持たせない理由は、あちらが同梱JSONで総入れ替えされる前提のテーブルで、
/// ストアを作り直したときに復元する術が無くなるため。原本は必ずこちらに残す。
@Model
final class UserWord {
    /// `WordMaster.wordId` と共有するID。同梱データと衝突しないよう接頭辞を付ける。
    @Attribute(.unique) var wordId: String

    var word: String
    var meaning: String
    var example: String

    var categoryRaw: String
    var partOfSpeechRaw: String

    var createdAt: Date
    var updatedAt: Date

    init(
        wordId: String = UserWord.makeId(),
        word: String,
        meaning: String,
        example: String = "",
        category: FrequencyRank = .c,
        partOfSpeech: PartOfSpeech = .noun,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.wordId = wordId
        self.word = word
        self.meaning = meaning
        self.example = example
        self.categoryRaw = category.rawValue
        self.partOfSpeechRaw = partOfSpeech.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func makeId() -> String { "USER_\(UUID().uuidString)" }

    var category: FrequencyRank {
        get { FrequencyRank(rawValue: categoryRaw) ?? .c }
        set { categoryRaw = newValue.rawValue }
    }

    var partOfSpeech: PartOfSpeech {
        get { PartOfSpeech(rawValue: partOfSpeechRaw) ?? .other }
        set { partOfSpeechRaw = newValue.rawValue }
    }
}
