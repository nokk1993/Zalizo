import Foundation
import SwiftData

enum ZalizoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    // Add `MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)` here
    // (or `.custom`) when the schema changes.
    static var stages: [MigrationStage] { [] }
}

enum Persistence {
    static let storeFileName = "Zalizo.store"

    /// Creates the on-disk container. Throws instead of crashing so the UI can show a friendly error.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // Application Support does not exist on a fresh install.
            let directory = URL.applicationSupportDirectory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: storeFileName)
            // No CloudKit: Personal Team signing has no iCloud entitlement.
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: ZalizoMigrationPlan.self, configurations: [configuration])
    }

    /// Returns the single profile/settings rows, creating them on first launch.
    static func bootstrap(_ context: ModelContext) throws {
        if try context.fetchCount(FetchDescriptor<UserProfile>()) == 0 {
            context.insert(UserProfile())
        }
        if try context.fetchCount(FetchDescriptor<AppSettings>()) == 0 {
            context.insert(AppSettings())
        }
        try context.save()
    }
}
