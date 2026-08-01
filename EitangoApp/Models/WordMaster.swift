import Foundation
import SwiftData

/// 単語マスターデータ。アプリ更新時に同梱JSONで丸ごとUpsertされる Read-Only 想定のテーブル。
/// `UserProgress` とは `wordId` (String) でのみ緩く結びつけ、SwiftDataの `@Relationship` は張らない。
/// 理由: リレーションを張ると WordMaster の delete/upsert 時に UserProgress へカスケードが波及するリスクがあるため、
/// 「マスターは総入れ替え、学習履歴は絶対保持」という要件上、意図的に疎結合にしている。
@Model
final class WordMaster {
    /// 英検2級単語帳内で一意なID（例: "EIKEN_G2_0001"）。JSON側の主キーと一致させる。
    @Attribute(.unique) var wordId: String

    var word: String
    var meaning: String
    var example: String

    /// 過去問での出題回数（単語詳細に表示）
    var frequencyCount: Int

    /// 頻出度ランク A/B/C（生値で保持し、computedで enum 変換）
    var categoryRaw: String
    var partOfSpeechRaw: String

    /// マスターデータの更新検知用（seed JSON の updatedAt をそのまま保持）
    var updatedAt: Date

    init(
        wordId: String,
        word: String,
        meaning: String,
        example: String,
        frequencyCount: Int,
        category: FrequencyRank,
        partOfSpeech: PartOfSpeech,
        updatedAt: Date = .now
    ) {
        self.wordId = wordId
        self.word = word
        self.meaning = meaning
        self.example = example
        self.frequencyCount = frequencyCount
        self.categoryRaw = category.rawValue
        self.partOfSpeechRaw = partOfSpeech.rawValue
        self.updatedAt = updatedAt
    }

    var category: FrequencyRank {
        get { FrequencyRank(rawValue: categoryRaw) ?? .c }
        set { categoryRaw = newValue.rawValue }
    }

    var partOfSpeech: PartOfSpeech {
        get { PartOfSpeech(rawValue: partOfSpeechRaw) ?? .other }
        set { partOfSpeechRaw = newValue.rawValue }
    }
}
