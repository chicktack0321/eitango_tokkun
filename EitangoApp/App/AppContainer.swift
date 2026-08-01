import Foundation
import SwiftData

/// SwiftDataの ModelContainer を一元管理する。
/// スキーマ変更（カラム追加等）は SwiftData の軽量マイグレーションで多くは自動対応できるが、
/// カラムのリネームや型変更のような破壊的変更が必要になった時点で
/// `SchemaMigrationPlan` を実装したVersionedSchemaに切り替える前提の置き場所として分離している。
@MainActor
enum AppContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            WordMaster.self,
            UserProgress.self,
            StudyLog.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            try WordMasterSeeder.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("ModelContainerの初期化に失敗しました: \(error)")
        }
    }()
}
