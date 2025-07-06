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
    static let externalSource = "externalSource" // Legacy: BYTES_LIST
    static let externalSourceAssets = "externalSourceAssets" // New: ASSET_LIST
    static let sharedCreationID = "sharedCreationID"
    static let isPublic = "isPublic"
}

@MainActor
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
                item.publicRecordName = nil
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
        record[SharedCreationField.isPublic] = item.isPublic as CKRecordValue
        
        var assets: [CKAsset] = []
        if let dataSources = item.dataSources {
            for dataSource in dataSources {
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent(UUID().uuidString)
                do {
                    try dataSource.data.write(to: tempURL)
                    let asset = CKAsset(fileURL: tempURL)
                    assets.append(asset)
                } catch {
                    logger.error("Failed to write data to temporary file for CKAsset creation: \(error.localizedDescription)")
                }
            }
        }
        
        if !assets.isEmpty {
            record[SharedCreationField.externalSourceAssets] = assets as CKRecordValue
        } else {
            record[SharedCreationField.externalSourceAssets] = nil
        }
        record[SharedCreationField.externalSource] = nil // Set legacy field to nil
        
        do {
            let savedRecord = try await publicDB.save(record)
            logger.info("Successfully saved record \(savedRecord.recordID.recordName) for item \(item.name).")
            
            // Update SwiftData model with CloudKit metadata
            item.publicRecordName = savedRecord.recordID.recordName
            
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
    
    /// Deletes a SharedCreation from both CloudKit public database and local SwiftData store
    /// - Parameter sharedCreation: The SharedCreation to delete
    /// - Throws: An error if deletion from CloudKit fails or if saving to SwiftData fails
    func deleteSharedCreation(_ sharedCreation: SharedCreation) async throws {
        let recordName = sharedCreation.publicRecordName
        if recordName == nil {
            return
        }
        logger.debug("Attempting to delete SharedCreation with recordName: \(recordName!)")
        
        // First, find the local SharedCreation by recordName
        let descriptor = FetchDescriptor<SharedCreation>(
            predicate: #Predicate<SharedCreation> { creation in
                creation.publicRecordName == recordName
            }
        )
        
        let localSharedCreations: [SharedCreation]
        do {
            localSharedCreations = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch local SharedCreation with recordName \(recordName!): \(error.localizedDescription)")
            throw error
        }
        
        guard let localSharedCreation = localSharedCreations.first else {
            logger.warning("No local SharedCreation found with recordName \(recordName!)")
            // Still try to delete from CloudKit in case it exists there
            try await deleteItemFromPublicCloud(recordName: recordName!)
            return
        }
        
        var cloudKitDeleteSuccessful = false
        
        // Delete from CloudKit
        do {
            try await deleteItemFromPublicCloud(recordName: recordName!)
            logger.info("Successfully deleted record \(recordName!) from CloudKit for SharedCreation \(localSharedCreation.name)")
            cloudKitDeleteSuccessful = true
        } catch {
            logger.error("Failed to delete record \(recordName!) from CloudKit: \(error.localizedDescription)")
            // Don't throw here - we'll try to delete locally and let the user know about the CloudKit failure
            cloudKitDeleteSuccessful = false
        }
        
        // Only delete from local store if CloudKit deletion was successful
        if cloudKitDeleteSuccessful {
            // Delete from local SwiftData store
            modelContext.delete(localSharedCreation)
            
            do {
                try modelContext.save()
                logger.info("Successfully deleted SharedCreation \(localSharedCreation.name) from local store")
            } catch {
                logger.error("Failed to save ModelContext after deleting SharedCreation \(localSharedCreation.name): \(error.localizedDescription)")
                throw error
            }
        } else {
            // CloudKit deletion failed, don't delete locally to maintain consistency
            throw NSError(domain: "CloudKitSync", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Failed to delete from CloudKit. Local copy preserved for retry."
            ])
        }
    }
    
    /// Checks if a SharedCreation can be deleted (i.e., it was created by the current user)
    /// - Parameter recordName: The CloudKit record name of the SharedCreation to check
    /// - Returns: true if the SharedCreation can be deleted, false otherwise
    func canDeleteSharedCreation(recordName: String) -> Bool {
        let descriptor = FetchDescriptor<SharedCreation>(
            predicate: #Predicate<SharedCreation> { creation in
                creation.publicRecordName == recordName
            }
        )
        
        do {
            let localSharedCreations = try modelContext.fetch(descriptor)
            guard let localSharedCreation = localSharedCreations.first else {
                return false // No local record found, cannot delete
            }
            return SharedCreation.isCreatedByCurrentUser(id: localSharedCreation.id, modelContext: modelContext)
        } catch {
            logger.error("Failed to fetch local SharedCreation with recordName \(recordName): \(error.localizedDescription)")
            return false
        }
    }
    
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
    
    // MARK: - Fetch from CloudKit by SharedCreation.id
    
    /// Fetches a specific SharedCreationRecord from CloudKit by its original SwiftData model ID (UUID)
    /// and returns a SharedCreation object without saving it locally.
    /// - Parameter sharedCreationID: The UUID (id property) of the SharedCreation model to fetch.
    /// - Returns: A SharedCreation object populated with data from CloudKit.
    /// - Throws: An error if fetching from CloudKit fails or if no matching record is found.
    func fetchSharedCreation(bySharedCreationID idToFetch: UUID) async throws -> SharedCreation {
        logger.debug("Attempting to fetch SharedCreation by id \(idToFetch.uuidString).")
        
        let predicate = NSPredicate(format: "%K == %@", SharedCreationField.sharedCreationID, idToFetch.uuidString)
        let query = CKQuery(recordType: CloudKitRecordType.sharedCreation, predicate: predicate)
        
        let fetchedRecord: CKRecord
        do {
            let (matchResults, _) = try await publicDB.records(matching: query, desiredKeys: nil, resultsLimit: 1)
            
            if let firstMatch = matchResults.first {
                switch firstMatch.1 {
                case .success(let record):
                    fetchedRecord = record
                    logger.info("Successfully fetched record \(fetchedRecord.recordID.recordName) for sharedCreationID \(idToFetch.uuidString).")
                case .failure(let error):
                    logger.error("Error in fetched result for sharedCreationID \(idToFetch.uuidString): \(error.localizedDescription)")
                    throw error
                }
            } else {
                logger.warning("No record found in public CloudKit database for sharedCreationID \(idToFetch.uuidString).")
                throw CKError(.unknownItem)
            }
        } catch {
            logger.error("Error querying/fetching record by sharedCreationID \(idToFetch.uuidString) from public CloudKit: \(error.localizedDescription)")
            throw error
        }
        
        let name = fetchedRecord[SharedCreationField.name] as? String ?? "Untitled from Cloud"
        let prompt = fetchedRecord[SharedCreationField.prompt] as? String ?? ""
        let desc = fetchedRecord[SharedCreationField.desc] as? String
        let isPublic = fetchedRecord[SharedCreationField.isPublic] as? Bool ?? false
        
        let sharedCreation = SharedCreation(
            id: idToFetch,
            name: name,
            prompt: prompt,
            desc: desc,
            isPublic: isPublic
        )
        
        var dataSources: [DataSource] = []
        // Try fetching from new asset field first
        if let assets = fetchedRecord[SharedCreationField.externalSourceAssets] as? [CKAsset] {
            logger.debug("Fetching from new externalSourceAssets field.")
            for asset in assets {
                if let fileURL = asset.fileURL,
                   let data = try? Data(contentsOf: fileURL) {
                    let dataSource = DataSource(data: data)
                    dataSources.append(dataSource)
                }
            }
        }
        // Fallback to old data field
        else if let dataList = fetchedRecord[SharedCreationField.externalSource] as? [Data] {
            logger.debug("Fetching from legacy externalSource field.")
            for data in dataList {
                let dataSource = DataSource(data: data)
                dataSources.append(dataSource)
            }
        }
        sharedCreation.dataSources = dataSources
        sharedCreation.publicRecordName = fetchedRecord.recordID.recordName
        
        return sharedCreation
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
            isPublic: fetchedRecord[SharedCreationField.isPublic] as? Bool ?? false
        )
        
        var dataSources: [DataSource] = []
        if let assets = fetchedRecord[SharedCreationField.externalSourceAssets] as? [CKAsset] {
            logger.debug("Fetching from new externalSourceAssets field for local copy.")
            for asset in assets {
                if let fileURL = asset.fileURL, let data = try? Data(contentsOf: fileURL) {
                    dataSources.append(DataSource(data: data))
                }
            }
        } else if let dataList = fetchedRecord[SharedCreationField.externalSource] as? [Data] {
            logger.debug("Fetching from legacy externalSource field for local copy.")
            dataSources = dataList.map { DataSource(data: $0) }
        }
        tempSharedCreation.dataSources = dataSources
        
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
            isPublic: fetchedRecord[SharedCreationField.isPublic] as? Bool ?? false
        )
        
        var dataSources: [DataSource] = []
        if let assets = fetchedRecord[SharedCreationField.externalSourceAssets] as? [CKAsset] {
            logger.debug("Fetching from new externalSourceAssets field for local copy.")
            for asset in assets {
                if let fileURL = asset.fileURL, let data = try? Data(contentsOf: fileURL) {
                    dataSources.append(DataSource(data: data))
                }
            }
        } else if let dataList = fetchedRecord[SharedCreationField.externalSource] as? [Data] {
            logger.debug("Fetching from legacy externalSource field for local copy.")
            dataSources = dataList.map { DataSource(data: $0) }
        }
        tempSharedCreation.dataSources = dataSources
        
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
    
    // MARK: - Fetch All Public SharedCreations
    
    /// Fetches all SharedCreationRecords from the public CloudKit database
    /// - Parameter limit: Maximum number of records to fetch (optional, defaults to 50)
    /// - Returns: An array of SharedCreation objects populated with data from CloudKit
    /// - Throws: An error if fetching from CloudKit fails
    func fetchAllPublicSharedCreations(limit: Int = 50) async throws -> [SharedCreation] {
        logger.debug("Attempting to fetch all public SharedCreations with limit: \(limit)")
        
        let query = CKQuery(recordType: CloudKitRecordType.sharedCreation, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        var allSharedCreations: [SharedCreation] = []
        
        do {
            let (matchResults, _) = try await publicDB.records(matching: query, desiredKeys: nil, resultsLimit: limit)
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    let sharedCreation = try await convertRecordToSharedCreation(record)
                    allSharedCreations.append(sharedCreation)
                case .failure(let error):
                    logger.error("Error in fetched result: \(error.localizedDescription)")
                    // Continue with other records even if one fails
                    continue
                }
            }
            
            logger.info("Successfully fetched \(allSharedCreations.count) public SharedCreations")
            return allSharedCreations
            
        } catch {
            logger.error("Error fetching all public SharedCreations: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Helper method to convert a CKRecord to a SharedCreation object
    /// - Parameter record: The CKRecord to convert
    /// - Returns: A SharedCreation object populated with data from the record
    private func convertRecordToSharedCreation(_ record: CKRecord) async throws -> SharedCreation {
        let cloudUUIDString = record[SharedCreationField.sharedCreationID] as? String
        let id = (cloudUUIDString != nil ? UUID(uuidString: cloudUUIDString!) : UUID()) ?? UUID()
        
        let name = record[SharedCreationField.name] as? String ?? "Untitled from Cloud"
        let prompt = record[SharedCreationField.prompt] as? String ?? ""
        let desc = record[SharedCreationField.desc] as? String
        let isPublic = record[SharedCreationField.isPublic] as? Bool ?? false
        
        let sharedCreation = SharedCreation(
            id: id,
            name: name,
            prompt: prompt,
            desc: desc,
            isPublic: isPublic
        )
        
        // Handle external sources (both new and legacy format)
        var dataSources: [DataSource] = []
        if let assets = record[SharedCreationField.externalSourceAssets] as? [CKAsset] {
            logger.debug("Processing externalSourceAssets for record \(record.recordID.recordName)")
            for asset in assets {
                if let fileURL = asset.fileURL,
                   let data = try? Data(contentsOf: fileURL) {
                    let dataSource = DataSource(data: data)
                    dataSources.append(dataSource)
                }
            }
        } else if let dataList = record[SharedCreationField.externalSource] as? [Data] {
            logger.debug("Processing legacy externalSource for record \(record.recordID.recordName)")
            for data in dataList {
                let dataSource = DataSource(data: data)
                dataSources.append(dataSource)
            }
        }
        
        sharedCreation.dataSources = dataSources
        sharedCreation.publicRecordName = record.recordID.recordName
        
        // Set modification date from CloudKit record
        if let modificationDate = record.modificationDate {
            sharedCreation.lastModified = modificationDate
        }
        
        return sharedCreation
    }
    
    // MARK: - Cleanup Functions
    
    /// Cleans up local SharedCreations that no longer exist in CloudKit
    /// This function fetches all local SharedCreations with publicRecordName and verifies they still exist in CloudKit
    /// If they don't exist in CloudKit, they are removed from local storage
    func cleanupOrphanedLocalSharedCreations() async throws {
        logger.debug("Starting cleanup of orphaned local SharedCreations")
        
        // Fetch all local SharedCreations that have a publicRecordName
        let descriptor = FetchDescriptor<SharedCreation>(
            predicate: #Predicate<SharedCreation> { creation in
                creation.publicRecordName != nil
            }
        )
        
        let localSharedCreations: [SharedCreation]
        do {
            localSharedCreations = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch local SharedCreations: \(error.localizedDescription)")
            throw error
        }
        
        logger.info("Found \(localSharedCreations.count) local SharedCreations with publicRecordName")
        
        var deletedCount = 0
        
        for sharedCreation in localSharedCreations {
            guard let recordName = sharedCreation.publicRecordName else { continue }
            
            // Check if the record still exists in CloudKit
            let recordID = CKRecord.ID(recordName: recordName)
            
            do {
                _ = try await publicDB.record(for: recordID)
                // Record exists in CloudKit, keep the local copy
                logger.trace("Record \(recordName) still exists in CloudKit, keeping local copy")
            } catch let error as CKError where error.code == .unknownItem {
                // Record doesn't exist in CloudKit, remove local copy
                logger.info("Record \(recordName) no longer exists in CloudKit, removing local copy for SharedCreation: \(sharedCreation.name)")
                modelContext.delete(sharedCreation)
                deletedCount += 1
            } catch {
                // Other error, log but don't delete
                logger.warning("Error checking CloudKit record \(recordName): \(error.localizedDescription). Keeping local copy.")
            }
        }
        
        if deletedCount > 0 {
            do {
                try modelContext.save()
                logger.info("Successfully cleaned up \(deletedCount) orphaned local SharedCreations")
            } catch {
                logger.error("Failed to save ModelContext after cleanup: \(error.localizedDescription)")
                throw error
            }
        } else {
            logger.info("No orphaned local SharedCreations found")
        }
    }
}
