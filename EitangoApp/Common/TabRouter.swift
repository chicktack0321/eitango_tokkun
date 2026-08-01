import Observation

enum AppTab: Hashable {
    case home, wordList, quiz, typing, listening
}

/// ホーム画面の「4択クイズを始める」等のクイックアクションから、
/// TabViewの選択タブをコード側から切り替えるための共有ルーター。
@Observable
@MainActor
final class TabRouter {
    var selectedTab: AppTab = .home
}
