import Foundation

/// 頻出度ランク（過去問での出題頻度グループ）
enum FrequencyRank: String, Codable, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"
    case c = "C"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a: return "頻出A"
        case .b: return "頻出B"
        case .c: return "頻出C"
        }
    }
}

enum PartOfSpeech: String, Codable, CaseIterable, Identifiable {
    case noun
    case verb
    case adjective
    case adverb
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noun: return "名詞"
        case .verb: return "動詞"
        case .adjective: return "形容詞"
        case .adverb: return "副詞"
        case .other: return "その他"
        }
    }
}

/// 単語ごとの学習ステータス
enum LearningStatus: String, Codable, CaseIterable, Identifiable {
    case notStudied   // 未学習
    case memorized     // 覚えた
    case needsReview   // 要復習

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notStudied: return "未学習"
        case .memorized: return "覚えた"
        case .needsReview: return "要復習"
        }
    }
}
