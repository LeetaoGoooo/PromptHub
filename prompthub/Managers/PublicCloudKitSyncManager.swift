import CloudKit
import OSLog
import SwiftData

enum CloudKitRecordType {
    static let sharedCreation = "SharedCreationRecord"
}

enum SharedCreationField {
    static let name = "name"
    static let prompt = "prompt"
    static let desc = "desc"
    static let externalSource = "externalSource"
    static let sharedCreationID = "sharedCreationID"
}

class PublicCloudKitSyncManager {
    private let container: CKContainer
    let publicDB: CKDatabase
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PublicCloudKitSyncManager")

    init(containerIdentifier: String, modelContext: ModelContext) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.publicDB = container.publicCloudDatabase
        self.modelContext = modelContext
        logger.info("PublicCloudKitSyncManager initialized for container: \(containerIdentifier)")
    }

    // MARK: - SwiftData to CloudKit (Push)

    func pushItemToPublicCloud(_ item: SharedCreation) async throws {
        logger.debug("Attempting to push item: \(item.name) (ID: \(item.id.uuidString))")
        var record: CKRecord // Use var to allow reassignment

        if let recordName = item.publicRecordName {
            do {
                record = try await publicDB.record(for: CKRecord.ID(recordName: recordName))
                logger.trace("Found existing record: \(record.recordID.recordName) for item \(item.name)")
            } catch let error as CKError where error.code == .unknownItem {
                logger.info("Record \(recordName) not found for item \(item.name). Assuming it was deleted or name changed. Creating new record.")
                record = CKRecord(recordType: CloudKitRecordType.sharedCreation) // Create new
                // Clear local CloudKit metadata as we're effectively creating a new link
                item.publicRecordName = nil
                item.lastModifiedInCloudTimestamp = nil
            } catch {
                logger.error("Error fetching record \(recordName) for item \(item.name): \(error.localizedDescription)")
                throw error
            }
        } else {
            record = CKRecord(recordType: CloudKitRecordType.sharedCreation)
            logger.trace("Creating new record for item \(item.name) as no publicRecordName was set.")
        }

        record[SharedCreationField.name] = item.name as CKRecordValue
        record[SharedCreationField.prompt] = item.prompt as CKRecordValue
        record[SharedCreationField.desc] = item.desc as CKRecordValue? // Handles nil
        record[SharedCreationField.sharedCreationID] = item.id.uuidString as CKRecordValue

        // TODO: use CKAsset
//        if let sources = item.externalSource, !sources.isEmpty {
//            record[SharedCreationField.externalSource] = sources as CKRecordValue
//        } else {
//            record[SharedCreationField.externalSource] = nil // Explicitly nil if empty or nil
//        }

        do {
            let savedRecord = try await publicDB.save(record)
            logger.info("Successfully saved record \(savedRecord.recordID.recordName) for item \(item.name).")

            // Update SwiftData model with CloudKit metadata
            item.publicRecordName = savedRecord.recordID.recordName
            if let tag = savedRecord.recordChangeTag {
                item.lastModifiedInCloudTimestamp = Data(tag.utf8)
            } else {
                item.lastModifiedInCloudTimestamp = nil
            }

            logger.debug("Updated SwiftData item \(item.name) with CloudKit metadata. ModelContext needs saving by caller.")

        } catch let error as CKError {
            logger.error("CKError pushing item \(item.name) to public cloud: \(error.localizedDescription). Code: \(error.code.rawValue)")
            if error.code == .serverRecordChanged {
                logger.warning("Server record changed for \(item.name). Conflict detected. Server version is in error.serverRecord. Implement conflict resolution.")
            }
            throw error // Rethrow to allow caller to handle (e.g., UI update)
        } catch {
            logger.error("Generic error pushing item \(item.name) to public cloud: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Delete

    func deleteItemFromPublicCloud(recordName: String) async throws {
        let recordID = CKRecord.ID(recordName: recordName)
        logger.debug("Attempting to delete record: \(recordName) from public cloud.")
        do {
            try await publicDB.deleteRecord(withID: recordID)
            logger.info("Successfully deleted record \(recordName) from public cloud.")
        } catch let error as CKError where error.code == .unknownItem {
            logger.warning("Record \(recordName) not found for deletion, assuming already deleted or never existed.")
            // This is often not an error you need to propagate harshly
        } catch {
            logger.error("Error deleting record \(recordName) from public cloud: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Fetch from CloudKit and Create Local Copies

    /// Fetches a specific SharedCreationRecord from CloudKit by its recordName,
    /// then creates local Prompt and PromptHistory objects in SwiftData.
    /// - Parameter recordName: The CKRecord.ID.recordName of the SharedCreationRecord to fetch.
    /// - Returns: A tuple containing the newly created local Prompt and PromptHistory.
    /// - Throws: An error if fetching from CloudKit fails or if saving to SwiftData fails.
    func fetchAndCreateLocalCopy(fromRecordName recordName: String) async throws -> (prompt: Prompt, promptHistory: PromptHistory) {
        logger.debug("Attempting to fetch record \(recordName) and create local copy.")
        let recordID = CKRecord.ID(recordName: recordName)

        let fetchedRecord: CKRecord
        do {
            fetchedRecord = try await publicDB.record(for: recordID)
            logger.info("Successfully fetched record \(recordName).")
        } catch let error as CKError where error.code == .unknownItem {
            logger.error("Record \(recordName) not found in public CloudKit database.")
            throw error // Or a custom error like ItemNotFoundError
        } catch {
            logger.error("Error fetching record \(recordName) from public CloudKit: \(error.localizedDescription)")
            throw error
        }

        let cloudUUIDString = fetchedRecord[SharedCreationField.sharedCreationID] as? String
        let tempSharedCreationID = (cloudUUIDString != nil ? UUID(uuidString: cloudUUIDString!) : UUID()) ?? UUID()

        let tempSharedCreation = SharedCreation(
            id: tempSharedCreationID, // Use the ID from the cloud record if it was stored
            name: fetchedRecord[SharedCreationField.name] as? String ?? "Untitled from Cloud",
            prompt: fetchedRecord[SharedCreationField.prompt] as? String ?? "",
            desc: fetchedRecord[SharedCreationField.desc] as? String,
        )

        // Use the makeLocalCopy() method to get the Prompt and PromptHistory
        let (newPrompt, newPromptHistory) = tempSharedCreation.makeLocalCopy()

        // TODO: duplicated issue
        modelContext.insert(newPrompt)
        modelContext.insert(newPromptHistory)

        do {
            try modelContext.save()
            logger.info("Successfully created and saved local Prompt (\(newPrompt.name)) and PromptHistory from record \(recordName).")
            return (newPrompt, newPromptHistory)
        } catch {
            logger.error("Failed to save ModelContext after creating local copies from record \(recordName): \(error.localizedDescription)")
            modelContext.delete(newPrompt) // Attempt to clean up if save failed
            modelContext.delete(newPromptHistory)
            throw error
        }
    }

    // MARK: - Fetch from CloudKit by SharedCreation.id and Create Local Copies

    /// Fetches a specific SharedCreationRecord from CloudKit by its original SwiftData model ID (UUID),
    /// then creates local Prompt and PromptHistory objects in SwiftData.
    /// - Parameter sharedCreationID: The UUID (id property) of the SharedCreation model to fetch.
    /// - Returns: A tuple containing the newly created local Prompt and PromptHistory.
    /// - Throws: An error if fetching from CloudKit fails, if no matching record is found, or if saving to SwiftData fails.
    func fetchAndCreateLocalCopy(bySharedCreationID idToFetch: UUID) async throws -> (prompt: Prompt, promptHistory: PromptHistory) {
        logger.debug("Attempting to fetch record by SharedCreation.id \(idToFetch.uuidString) and create local copy.")

        let predicate = NSPredicate(format: "%K == %@", SharedCreationField.sharedCreationID, idToFetch.uuidString)
        let query = CKQuery(recordType: CloudKitRecordType.sharedCreation, predicate: predicate)

        let fetchedRecord: CKRecord
        do {
            let (matchResults, _) = try await publicDB.records(matching: query, desiredKeys: nil, resultsLimit: 1)

            if let firstMatch = matchResults.first {
                switch firstMatch.1 { // firstMatch is (CKRecord.ID, Result<CKRecord, Error>)
                case .success(let record):
                    fetchedRecord = record
                    logger.info("Successfully fetched record \(fetchedRecord.recordID.recordName) for sharedCreationID \(idToFetch.uuidString).")
                case .failure(let error):
                    logger.error("Error in fetched result for sharedCreationID \(idToFetch.uuidString): \(error.localizedDescription)")
                    throw error
                }
            } else {
                // No record found matching the UUID
                logger.warning("No record found in public CloudKit database for sharedCreationID \(idToFetch.uuidString).")
                throw CKError(.unknownItem)
            }
        } catch {
            logger.error("Error querying/fetching record by sharedCreationID \(idToFetch.uuidString) from public CloudKit: \(error.localizedDescription)")
            throw error
        }

        let tempSharedCreation = SharedCreation(
            id: idToFetch, // Use the ID we queried for
            name: fetchedRecord[SharedCreationField.name] as? String ?? "Untitled from Cloud",
            prompt: fetchedRecord[SharedCreationField.prompt] as? String ?? "",
            desc: fetchedRecord[SharedCreationField.desc] as? String,
        )

        let (newPrompt, newPromptHistory) = tempSharedCreation.makeLocalCopy()

        // TODO: Duplicate checking for Prompt/PromptHistory

        modelContext.insert(newPrompt)
        modelContext.insert(newPromptHistory)

        do {
            try modelContext.save()
            logger.info("Successfully created and saved local Prompt (\(newPrompt.name)) and PromptHistory from record with sharedCreationID \(idToFetch.uuidString).")
            return (newPrompt, newPromptHistory)
        } catch {
            logger.error("Failed to save ModelContext after creating local copies from record with sharedCreationID \(idToFetch.uuidString): \(error.localizedDescription)")
            modelContext.delete(newPrompt)
            modelContext.delete(newPromptHistory)
            throw error
        }
    }
}
