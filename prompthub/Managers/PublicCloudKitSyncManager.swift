import CloudKit
import OSLog
import SwiftData

enum CloudKitRecordType {
    static let sharedCreation = "SharedCreationRecord"
}

enum SharedCreationField {
    static let name                = "name"
    static let prompt              = "prompt"
    static let desc                = "desc"
    static let externalSource      = "externalSource"
    static let externalSourceAssets = "externalSourceAssets"
    static let sharedCreationID    = "sharedCreationID"
    static let isPublic            = "isPublic"
}

@MainActor
class PublicCloudKitSyncManager {
    private let container: CKContainer
    let publicDB: CKDatabase
    let modelContext: ModelContext
    let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.duck.leetao.prompthub",
        category: "PublicCloudKitSyncManager"
    )

    init(containerIdentifier: String, modelContext: ModelContext) throws {
        try CloudKitAccess.ensureContainerAccess(identifier: containerIdentifier)
        self.container   = CKContainer(identifier: containerIdentifier)
        self.publicDB    = container.publicCloudDatabase
        self.modelContext = modelContext
        logger.info("PublicCloudKitSyncManager initialized for container: \(containerIdentifier)")
    }

    // MARK: - Push

    func pushItemToPublicCloud(_ item: SharedCreation) async throws {
        logger.debug("Attempting to push item: \(item.name) (ID: \(item.id.uuidString))")
        var record: CKRecord

        if let recordName = item.publicRecordName {
            do {
                record = try await publicDB.record(for: CKRecord.ID(recordName: recordName))
                logger.trace("Found existing record: \(record.recordID.recordName) for item \(item.name)")
            } catch let error as CKError where error.code == .unknownItem {
                logger.info("Record \(recordName) not found for item \(item.name). Creating new record.")
                record = CKRecord(recordType: CloudKitRecordType.sharedCreation)
                item.publicRecordName = nil
            } catch {
                logger.error("Error fetching record \(recordName) for item \(item.name): \(error.localizedDescription)")
                throw error
            }
        } else {
            record = CKRecord(recordType: CloudKitRecordType.sharedCreation)
            logger.trace("Creating new record for item \(item.name).")
        }

        record[SharedCreationField.name]            = item.name as CKRecordValue
        record[SharedCreationField.prompt]          = item.prompt as CKRecordValue
        record[SharedCreationField.desc]            = item.desc as CKRecordValue?
        record[SharedCreationField.sharedCreationID] = item.id.uuidString as CKRecordValue
        record[SharedCreationField.isPublic]        = item.isPublic as CKRecordValue

        var assets: [CKAsset] = []
        if let dataSources = item.dataSources {
            for dataSource in dataSources {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                do {
                    try dataSource.data.write(to: tempURL)
                    assets.append(CKAsset(fileURL: tempURL))
                } catch {
                    logger.error("Failed to write data to temporary file: \(error.localizedDescription)")
                }
            }
        }
        record[SharedCreationField.externalSourceAssets] = assets.isEmpty ? nil : assets as CKRecordValue
        record[SharedCreationField.externalSource]       = nil

        do {
            let savedRecord = try await publicDB.save(record)
            item.publicRecordName = savedRecord.recordID.recordName
            logger.info("Successfully saved record \(savedRecord.recordID.recordName) for item \(item.name).")
        } catch let error as CKError {
            logger.error("CKError pushing item \(item.name): \(error.localizedDescription). Code: \(error.code.rawValue)")
            throw error
        } catch {
            logger.error("Error pushing item \(item.name): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Delete (atomic)

    func deleteItemFromPublicCloud(recordName: String) async throws {
        let recordID = CKRecord.ID(recordName: recordName)
        logger.debug("Attempting to delete record: \(recordName).")
        do {
            try await publicDB.deleteRecord(withID: recordID)
            logger.info("Successfully deleted record \(recordName).")
        } catch let error as CKError where error.code == .unknownItem {
            logger.warning("Record \(recordName) not found — assuming already deleted.")
        } catch {
            logger.error("Error deleting record \(recordName): \(error.localizedDescription)")
            throw error
        }
    }
}
