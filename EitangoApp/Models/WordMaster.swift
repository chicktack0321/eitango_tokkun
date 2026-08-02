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

    /// 同梱JSON由来か、ユーザーが自分で追加した語か。
    /// seedのUpsertは「JSONに無い語」を削除するため、この区別が無いと
    /// アプリ更新のたびにユーザーの追加分が消える。
    /// 既存ストアからのアップデートでも既定値が入るよう、省略可能な初期値を持たせている。
    var sourceRaw: String = WordSource.bundled.rawValue

    /// 語彙階層（1:基礎 / 2:架け橋 / 3:2級コア）。
    /// 既存ストアからのアップデートでも既定値が入るよう、省略可能な初期値を持たせている。
    var tierRaw: Int = VocabularyTier.core.rawValue

    /// 出題トピック。苦手な分野だけを集中的に回すために使う。
    var domainRaw: String = VocabularyDomain.general.rawValue

    /// 熟語・句動詞かどうか（"take part in" のような複数語の見出し）
    var isIdiom: Bool = false

    init(
        wordId: String,
        word: String,
        meaning: String,
        example: String,
        frequencyCount: Int,
        category: FrequencyRank,
        partOfSpeech: PartOfSpeech,
        updatedAt: Date = .now,
        source: WordSource = .bundled,
        tier: VocabularyTier = .core,
        domain: VocabularyDomain = .general,
        isIdiom: Bool = false
    ) {
        self.wordId = wordId
        self.word = word
        self.meaning = meaning
        self.example = example
        self.frequencyCount = frequencyCount
        self.categoryRaw = category.rawValue
        self.partOfSpeechRaw = partOfSpeech.rawValue
        self.updatedAt = updatedAt
        self.sourceRaw = source.rawValue
        self.tierRaw = tier.rawValue
        self.domainRaw = domain.rawValue
        self.isIdiom = isIdiom
    }

    var source: WordSource {
        get { WordSource(rawValue: sourceRaw) ?? .bundled }
        set { sourceRaw = newValue.rawValue }
    }

    var tier: VocabularyTier {
        get { VocabularyTier(rawValue: tierRaw) ?? .core }
        set { tierRaw = newValue.rawValue }
    }

    var domain: VocabularyDomain {
        get { VocabularyDomain(rawValue: domainRaw) ?? .general }
        set { domainRaw = newValue.rawValue }
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
