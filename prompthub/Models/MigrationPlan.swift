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
    static var models: [any PersistentModel.Type] {
        [PromptV1.self, PromptHistoryV1.self, SharedCreationV1.self]
    }

    @Model
    class PromptV1 {
        var id: UUID;
        var name: String;
        var desc: String?;
        var link:String?;
        @Attribute(.externalStorage)
        var externalSource: [Data]?
        
        init(id: UUID = UUID(), name: String,desc:String? = nil, link: String? = nil, externalSource: [Data]? = nil) {
            self.id = id;
            self.name = name;
            self.link = link;
            self.desc = desc;
            self.externalSource = externalSource;
        }
    }

    @Model
    class PromptHistoryV1 {
        var id: UUID;
        var promptId: UUID;
        var prompt:String;
        var createdAt: Date;
        var updatedAt: Date;
        var version: Int;
        
        init(id: UUID = UUID(), promptId: UUID, prompt: String, createdAt: Date = Date(), updatedAt: Date = Date(), version: Int = 0) {
            self.id = id;
            self.promptId = promptId;
            self.prompt = prompt;
            self.createdAt = createdAt;
            self.updatedAt = updatedAt;
            self.version = version;
        }
    }

    @Model
    final class SharedCreationV1 {
        var id: UUID = UUID()
        var name: String = ""
        var prompt: String = ""
        var desc: String? = nil
        var externalSource: [Data]? = nil
        
        var publicRecordName: String?
        var lastModifiedInCloudTimestamp: Data?
        
        init(id: UUID = UUID(), name: String, prompt: String, desc: String? = nil, externalSource: [Data]? = nil, publicRecordName: String? = nil, lastModifiedInCloudTimestamp: Data? = nil) {
            self.id = id
            self.name = name
            self.prompt = prompt
            self.externalSource = externalSource
            self.desc = desc
            self.publicRecordName = publicRecordName
            self.lastModifiedInCloudTimestamp = lastModifiedInCloudTimestamp
        }
    }
}


enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Prompt.self, PromptHistory.self, ExternalSource.self, SharedCreation.self, DataSource.self] }
}


let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PromptHubMigrationPlan")

enum PromptHubMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    private static var tempLegacySources: [UUID: [Data]] = [:]
    private static var tempHistoryToPromptMapping: [UUID: UUID] = [:]
    private static var tempHistoryIdToPromptText: [UUID: String] = [:]
    private static var tempShareCreationLegacySources: [UUID: [Data]] = [:]

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }


    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            logger.info("[willMigrate V1->V6] Starting...")

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
            
            let oldShareCreations = try context.fetch(FetchDescriptor<SchemaV1.SharedCreationV1>())
            
            for oldShareCreation in oldShareCreations {
                if let sources = oldShareCreation.externalSource, !sources.isEmpty {
                    Self.tempShareCreationLegacySources[oldShareCreation.id] = sources;
                }
            }

            logger.info("[willMigrate V1->V6] Completed.")
        },
        didMigrate: { context in
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

            logger.info("[didMigrate V1->V6] Created new DataSource entities.")
            
            let newShareCreations = try context.fetch(FetchDescriptor<SharedCreation>())
            let shareCreationsById = Dictionary(uniqueKeysWithValues: newShareCreations.map({ ($0.id, $0) }))
            
            for (shareCreationId, sourcesData) in Self.tempShareCreationLegacySources {
                guard let targetShareCreation = shareCreationsById[shareCreationId] else { continue }
                for dataItem in sourcesData {
                    let newSource = DataSource(data: dataItem)
                    newSource.creation = targetShareCreation
                    context.insert(newSource)
                }
            }
            logger.info("[didMigrate V1->V6] Created new DataSource entities.")
            
            try context.save()

            Self.tempLegacySources.removeAll()
            Self.tempHistoryToPromptMapping.removeAll()
            Self.tempHistoryIdToPromptText.removeAll()
            Self.tempShareCreationLegacySources.removeAll()

            logger.info("[didMigrate V1->V6] Migration stage completed successfully.")
        }
    )
}
