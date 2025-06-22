//
//  MigrationPlan.swift
//  prompthub
//
//  Created by leetao on 2025/6/21.
//

import Foundation
import SwiftData
import OSLog


enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] { [PromptV1.self,PromptHistoryV1.self] }
    
    @Model
    class PromptV1 {
        var id: UUID
        var name: String
        
        
        init(id: UUID = UUID(), name: String) {
            self.id = id
            self.name = name
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
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    

    static var models: [any PersistentModel.Type] { [PromptV2.self,PromptHistoryV2.self,SharedCreationV2.self] }
    
    @Model
    class PromptV2 {
        var id: UUID
        var name: String
        var desc: String?
        var link: String?
        
        var externalSource: [Data]?

        
        init(id: UUID = UUID(), name: String, desc: String? = nil, link: String? = nil, externalSource: [Data]? = nil) {
            self.id = id
            self.name = name
            self.desc = desc
            self.link = link
            self.externalSource = externalSource
        }
    }
    
    @Model
    class PromptHistoryV2 {
        var id: UUID
        var prompt: String
        var promptId: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        
        
        init(id: UUID = UUID(),  promptId: UUID, prompt: String, createdAt: Date = .now, updatedAt: Date = .now, version: Int = 0, ) {
            self.id = id
            self.promptId = promptId
            self.prompt = prompt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.version = version
        }
    }
    
    
    @Model
    class SharedCreationV2 {
        var id: UUID = UUID()
        var name: String = ""
        var prompt: String = ""
        var desc: String? = nil

        
        init(id: UUID = UUID(), name: String, prompt: String, desc: String? = nil) {
            self.id = id
            self.name = name
            self.prompt = prompt
            self.desc = desc        }
    }
}


enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    
    static var models: [any PersistentModel.Type] { [Prompt.self, PromptHistory.self, ExternalSource.self, SharedCreation.self] }
}


// MARK: - Migration Plan

let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PromptHubMigrationPlan")

enum PromptHubMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }
    
    private static var tempLegacySources: [UUID: [Data]] = [:]
    private static var tempHistoryToPromptMapping: [UUID: UUID] = [:]
    private static var tempHistoryIdToPromptText: [UUID: String] = [:]

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.custom(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self,
        willMigrate: { context in
            logger.info("[willMigrate] Starting...")
            

            let oldPrompts = try context.fetch(FetchDescriptor<SchemaV2.PromptV2>())
            for oldPrompt in oldPrompts {
                if let sources = oldPrompt.externalSource, !sources.isEmpty {
                    Self.tempLegacySources[oldPrompt.id] = sources
                }
            }
            logger.info("[willMigrate] Stashed \(Self.tempLegacySources.count) prompts\' legacy sources.")
            
            let oldHistories = try context.fetch(FetchDescriptor<SchemaV2.PromptHistoryV2>())
            for oldHistory in oldHistories {
                Self.tempHistoryToPromptMapping[oldHistory.id] = oldHistory.promptId
                Self.tempHistoryIdToPromptText[oldHistory.id] = oldHistory.prompt
            }
            logger.info("[willMigrate] Stashed \(Self.tempHistoryToPromptMapping.count) history-to-prompt mappings.")
            logger.info("[willMigrate] Stashed \(Self.tempHistoryIdToPromptText.count) history prompt texts.")

            logger.info("[willMigrate] Completed.")
        },
        didMigrate: { context in
            logger.info("[didMigrate] Starting...")
            
            let newPrompts = try context.fetch(FetchDescriptor<Prompt>())
            let promptsById = Dictionary(uniqueKeysWithValues: newPrompts.map { ($0.id, $0) })
            
            for (promptId, sourcesData) in Self.tempLegacySources {
                guard let targetPrompt = promptsById[promptId] else {
                    logger.warning("[didMigrate] Could not find new prompt with ID \(promptId) to attach sources to.")
                    continue
                }
                
                for dataItem in sourcesData {
                    let newSource = ExternalSource(data: dataItem)
                    newSource.prompt = targetPrompt
                    context.insert(newSource)
                }
            }
            logger.info("[didMigrate] Created new ExternalSource entities for \(Self.tempLegacySources.count) prompts.")

            let newHistories = try context.fetch(FetchDescriptor<PromptHistory>())
            let historiesById = Dictionary(uniqueKeysWithValues: newHistories.map { ($0.id, $0) })
            
            for (historyId, promptId) in Self.tempHistoryToPromptMapping {
                guard let targetHistory = historiesById[historyId],
                      let targetPrompt = promptsById[promptId] else {
                    logger.warning("[didMigrate] Could not find entities for history-prompt mapping (\(historyId) -> \(promptId)).")
                    continue
                }
                targetHistory.prompt = targetPrompt
            }
            logger.info("[didMigrate] Re-established relationships for \(Self.tempHistoryToPromptMapping.count) history records.")

            for (historyId, promptText) in Self.tempHistoryIdToPromptText {
                guard let targetHistory = historiesById[historyId] else {
                    logger.warning("[didMigrate] Could not find new history with ID \(historyId) to update prompt text.")
                    continue
                }
                targetHistory.promptText = promptText
            }
            logger.info("[didMigrate] Updated prompt text for \(Self.tempHistoryIdToPromptText.count) history records.")

            try context.save()
            
            Self.tempLegacySources.removeAll()
            Self.tempHistoryToPromptMapping.removeAll()
            Self.tempHistoryIdToPromptText.removeAll()
            
            logger.info("[didMigrate] Migration stage completed, saved, and cleaned up successfully.")
        }
    )
}
