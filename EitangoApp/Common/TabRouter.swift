import Observation

enum AppTab: Hashable {
    case home, wordList, quiz, typing, listening
}

/// クイズの出題対象。
enum QuizScope {
    /// 復習期限が来た語を優先しつつ、足りなければ未学習の語で埋める（通常の学習）
    case mixed
    /// 復習期限が来た語だけを出題する。ホームの「復習する単語がN語あります」から入るときに使う。
    case reviewOnly

    var title: String {
        switch self {
        case .mixed: return "4択クイズ"
        case .reviewOnly: return "復習クイズ"
        }
    }
}

/// ホーム画面の「4択クイズを始める」等のクイックアクションから、
/// TabViewの選択タブをコード側から切り替えるための共有ルーター。
@Observable
@MainActor
final class TabRouter {
    var selectedTab: AppTab = .home

    /// 次にクイズ画面が開かれたときに、この条件で自動的に開始する。
    /// ホームの復習ボタンが「復習する」と言いながら通常出題を始めてしまうのを避けるため、
    /// 遷移とあわせて出題対象を渡している。
    var pendingQuizScope: QuizScope?

    func startQuiz(scope: QuizScope) {
        pendingQuizScope = scope
        selectedTab = .quiz
    }

    /// クイズ画面が受け取ったら消費する（戻ってくるたびに再開始しないように）
    func consumePendingQuizScope() -> QuizScope? {
        defer { pendingQuizScope = nil }
        return pendingQuizScope
    }
}
