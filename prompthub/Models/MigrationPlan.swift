//
//  MigrationPlan.swift
//  prompthub
//
//  Created by leetao on 2025/6/21.
//

import Foundation
import OSLog
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [PromptV1.self, PromptHistoryV1.self, SharedCreationV1.self] }

    @Model
    class PromptV1 {
        var id: UUID; var name: String; var desc: String?; var link: String?; @Attribute(.externalStorage) var externalSource: [Data]?
        init(id: UUID = UUID(), name: String, desc: String? = nil, link: String? = nil, externalSource: [Data]? = nil) { self.id = id; self.name = name; self.desc = desc; self.link = link; self.externalSource = externalSource }
    }

    @Model
    class PromptHistoryV1 {
        var id: UUID; var promptId: UUID; var prompt: String; var createdAt: Date; var updatedAt: Date; var version: Int
        init(id: UUID = UUID(), promptId: UUID, prompt: String, createdAt: Date = Date(), updatedAt: Date = Date(), version: Int = 0) { self.id = id; self.promptId = promptId; self.prompt = prompt; self.createdAt = createdAt; self.updatedAt = updatedAt; self.version = version }
    }

    @Model
    final class SharedCreationV1 {
        var id: UUID; var name: String; var prompt: String; var desc: String?; @Attribute(.externalStorage) var externalSource: [Data]?; var publicRecordName: String?; var lastModifiedInCloudTimestamp: Data?
        init(id: UUID = UUID(), name: String, prompt: String, desc: String? = nil, externalSource: [Data]? = nil, publicRecordName: String? = nil, lastModifiedInCloudTimestamp: Data? = nil) { self.id = id; self.name = name; self.prompt = prompt; self.desc = desc; self.externalSource = externalSource; self.publicRecordName = publicRecordName; self.lastModifiedInCloudTimestamp = lastModifiedInCloudTimestamp }
    }
}

enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)
    static var models: [any PersistentModel.Type] { [Prompt.self, PromptHistory.self, ExternalSource.self, SharedCreation.self] }
}

// MARK: - 简化后的迁移计划

let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PromptHubMigrationPlan")

enum PromptHubMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV6.self]
    }

    private static var tempLegacySources: [UUID: [Data]] = [:]
    private static var tempHistoryToPromptMapping: [UUID: UUID] = [:]
    private static var tempHistoryIdToPromptText: [UUID: String] = [:]

    static var stages: [MigrationStage] {
        [migrateV1toV6]
    }


    static let migrateV1toV6 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV6.self,
        willMigrate: { context in
            logger.info("[willMigrate V1->V6] Starting...")

            // 注意：这里要用 V1 的类型来抓取旧数据！
            let oldPrompts = try context.fetch(FetchDescriptor<SchemaV1.PromptV1>())
            for oldPrompt in oldPrompts {
                if let sources = oldPrompt.externalSource, !sources.isEmpty {
                    Self.tempLegacySources[oldPrompt.id] = sources
                }
            }
            logger.info("[willMigrate V1->V6] Stashed \(Self.tempLegacySources.count) prompts' legacy sources.")

            let oldHistories = try context.fetch(FetchDescriptor<SchemaV1.PromptHistoryV1>())
            for oldHistory in oldHistories {
                Self.tempHistoryToPromptMapping[oldHistory.id] = oldHistory.promptId
                Self.tempHistoryIdToPromptText[oldHistory.id] = oldHistory.prompt
            }
            logger.info("[willMigrate V1->V6] Stashed mappings for \(oldHistories.count) histories.")

            logger.info("[willMigrate V1->V6] Completed.")
        },
        didMigrate: { context in
            // didMigrate 部分的逻辑完全相同，因为它操作的是新版本(V6)的数据
            logger.info("[didMigrate V1->V6] Starting...")

            let newPrompts = try context.fetch(FetchDescriptor<Prompt>())
            let promptsById = Dictionary(uniqueKeysWithValues: newPrompts.map { ($0.id, $0) })

            for (promptId, sourcesData) in Self.tempLegacySources {
                guard let targetPrompt = promptsById[promptId] else { continue }
                for dataItem in sourcesData {
                    let newSource = ExternalSource(data: dataItem)
                    newSource.prompt = targetPrompt
                    context.insert(newSource)
                }
            }
            logger.info("[didMigrate V1->V6] Created new ExternalSource entities.")

            let newHistories = try context.fetch(FetchDescriptor<PromptHistory>())
            let historiesById = Dictionary(uniqueKeysWithValues: newHistories.map { ($0.id, $0) })

            for (historyId, promptId) in Self.tempHistoryToPromptMapping {
                guard let targetHistory = historiesById[historyId],
                      let targetPrompt = promptsById[promptId] else { continue }
                targetHistory.prompt = targetPrompt
            }
            logger.info("[didMigrate V1->V6] Re-established relationships for history records.")

            for (historyId, promptText) in Self.tempHistoryIdToPromptText {
                guard let targetHistory = historiesById[historyId] else { continue }
                targetHistory.promptText = promptText
            }
            logger.info("[didMigrate V1->V6] Updated prompt text for history records.")

            try context.save()

            Self.tempLegacySources.removeAll()
            Self.tempHistoryToPromptMapping.removeAll()
            Self.tempHistoryIdToPromptText.removeAll()

            logger.info("[didMigrate V1->V6] Migration stage completed successfully.")
        }
    )
}


enum DefaultStoreSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    // 只包含 Prompt 和 PromptHistory
    static var models: [any PersistentModel.Type] { [PromptV1.self, PromptHistoryV1.self] }
    
    // PromptV1: 这是 v1.0.0 时 default.store 中 Prompt 的真实结构
    @Model
    class PromptV1 {
        var id: UUID; var name: String; var desc: String?; var link: String?; @Attribute(.externalStorage) var externalSource: [Data]?
        init(id: UUID = UUID(), name: String, desc: String? = nil, link: String? = nil, externalSource: [Data]? = nil) { self.id = id; self.name = name; self.desc = desc; self.link = link; self.externalSource = externalSource }
    }
    
    // PromptHistoryV1: 结构是正确的
    @Model
    class PromptHistoryV1 {
        var id: UUID; var promptId: UUID; var prompt:String; var createdAt: Date; var updatedAt: Date; var version: Int
        init(id: UUID = UUID(), promptId: UUID, prompt: String, createdAt: Date = Date(), updatedAt: Date = Date(), version: Int = 0) { self.id = id; self.promptId = promptId; self.prompt = prompt; self.createdAt = createdAt; self.updatedAt = updatedAt; self.version = version }
    }
}

// MARK: - Default Store 迁移计划
enum DefaultStoreMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [DefaultStoreSchemaV1.self, SchemaV6.self] // 从V1直接到V6
    }
    
    // 这个迁移计划的自定义逻辑和 PromptHubMigrationPlan 完全一样，因为它们处理的是相同的模型变化
    // 为了不重复代码，我们可以直接引用它
    static var stages: [MigrationStage] {
        [PromptHubMigrationPlan.migrateV1toV6]
    }
}
