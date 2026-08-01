import SwiftUI
import SwiftData

@main
struct EitangoApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(AppContainer.shared)
    }
}

/// ソーシャル機能を一切持たないため、タブは「学習」に直結する最小構成にする
struct RootTabView: View {
    @State private var router = TabRouter()

    var body: some View {
        TabView(selection: Bindable(router).selectedTab) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
                .tag(AppTab.home)

            WordListView()
                .tabItem { Label("単語帳", systemImage: "text.book.closed") }
                .tag(AppTab.wordList)

            QuizView()
                .tabItem { Label("4択クイズ", systemImage: "checkmark.circle") }
                .tag(AppTab.quiz)

            TypingView()
                .tabItem { Label("タイピング", systemImage: "keyboard") }
                .tag(AppTab.typing)

            ListeningView()
                .tabItem { Label("聞き流し", systemImage: "headphones") }
                .tag(AppTab.listening)
        }
        .environment(router)
    }
}
