import CloudKit
import SwiftData

// MARK: - Fetch Operations

extension PublicCloudKitSyncManager {

    /// Fetches a SharedCreation from CloudKit by its model UUID without saving locally.
    func fetchSharedCreation(bySharedCreationID idToFetch: UUID) async throws -> SharedCreation {
        logger.debug("Fetching SharedCreation by id \(idToFetch.uuidString).")
        let predicate = NSPredicate(format: "%K == %@", SharedCreationField.sharedCreationID, idToFetch.uuidString)
        let query     = CKQuery(recordType: CloudKitRecordType.sharedCreation, predicate: predicate)

        let fetchedRecord = try await fetchFirstRecord(matching: query, id: idToFetch.uuidString)
        let sharedCreation = sharedCreationFromRecord(fetchedRecord, id: idToFetch)
        sharedCreation.dataSources     = dataSourcesFromRecord(fetchedRecord)
        sharedCreation.publicRecordName = fetchedRecord.recordID.recordName
        return sharedCreation
    }

    /// Fetches a CloudKit record by recordName and creates local SwiftData copies.
    func fetchAndCreateLocalCopy(fromRecordName recordName: String) async throws -> (prompt: Prompt, promptHistory: PromptHistory) {
        logger.debug("Fetching record \(recordName) to create local copy.")
        let fetchedRecord: CKRecord
        do {
            fetchedRecord = try await publicDB.record(for: CKRecord.ID(recordName: recordName))
            logger.info("Fetched record \(recordName).")
        } catch let error as CKError where error.code == .unknownItem {
            logger.error("Record \(recordName) not found.")
            throw error
        } catch {
            logger.error("Error fetching record \(recordName): \(error.localizedDescription)")
            throw error
        }

        let cloudUUIDString = fetchedRecord[SharedCreationField.sharedCreationID] as? String
        let tempID = cloudUUIDString.flatMap { UUID(uuidString: $0) } ?? UUID()
        let tempSharedCreation = sharedCreationFromRecord(fetchedRecord, id: tempID)
        tempSharedCreation.dataSources = dataSourcesFromRecord(fetchedRecord)
        return try await saveLocalCopy(of: tempSharedCreation, recordName: recordName)
    }

    /// Fetches a CloudKit record by model UUID and creates local SwiftData copies.
    func fetchAndCreateLocalCopy(bySharedCreationID idToFetch: UUID) async throws -> (prompt: Prompt, promptHistory: PromptHistory) {
        logger.debug("Fetching record by SharedCreation.id \(idToFetch.uuidString) to create local copy.")
        let predicate = NSPredicate(format: "%K == %@", SharedCreationField.sharedCreationID, idToFetch.uuidString)
        let query     = CKQuery(recordType: CloudKitRecordType.sharedCreation, predicate: predicate)

        let fetchedRecord = try await fetchFirstRecord(matching: query, id: idToFetch.uuidString)
        let tempSharedCreation = sharedCreationFromRecord(fetchedRecord, id: idToFetch)
        tempSharedCreation.dataSources = dataSourcesFromRecord(fetchedRecord)
        return try await saveLocalCopy(of: tempSharedCreation, recordName: fetchedRecord.recordID.recordName)
    }

    // MARK: - Private helpers

    private func fetchFirstRecord(matching query: CKQuery, id: String) async throws -> CKRecord {
        do {
            let (matchResults, _) = try await publicDB.records(matching: query, desiredKeys: nil, resultsLimit: 1)
            guard let firstMatch = matchResults.first else {
                logger.warning("No record found in CloudKit for id \(id).")
                throw CKError(.unknownItem)
            }
            switch firstMatch.1 {
            case .success(let record):
                logger.info("Fetched record \(record.recordID.recordName) for id \(id).")
                return record
            case .failure(let error):
                logger.error("Error in fetched result for id \(id): \(error.localizedDescription)")
                throw error
            }
        } catch {
            logger.error("Error querying CloudKit for id \(id): \(error.localizedDescription)")
            throw error
        }
    }

    func sharedCreationFromRecord(_ record: CKRecord, id: UUID) -> SharedCreation {
        SharedCreation(
            id: id,
            name:     record[SharedCreationField.name]     as? String ?? "Untitled from Cloud",
            prompt:   record[SharedCreationField.prompt]   as? String ?? "",
            desc:     record[SharedCreationField.desc]     as? String,
            isPublic: record[SharedCreationField.isPublic] as? Bool   ?? false
        )
    }

    func dataSourcesFromRecord(_ record: CKRecord) -> [DataSource] {
        if let assets = record[SharedCreationField.externalSourceAssets] as? [CKAsset] {
            return assets.compactMap { asset -> DataSource? in
                guard let fileURL = asset.fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
                return DataSource(data: data)
            }
        }
        if let dataList = record[SharedCreationField.externalSource] as? [Data] {
            return dataList.map { DataSource(data: $0) }
        }
        return []
    }

    private func saveLocalCopy(of tempSharedCreation: SharedCreation, recordName: String) async throws -> (prompt: Prompt, promptHistory: PromptHistory) {
        let (newPrompt, newPromptHistory) = tempSharedCreation.makeLocalCopy()
        modelContext.insert(newPrompt)
        modelContext.insert(newPromptHistory)
        do {
            try modelContext.save()
            logger.info("Saved local Prompt (\(newPrompt.name)) from record \(recordName).")
            return (newPrompt, newPromptHistory)
        } catch {
            logger.error("Failed to save ModelContext from record \(recordName): \(error.localizedDescription)")
            modelContext.delete(newPrompt)
            modelContext.delete(newPromptHistory)
            throw error
        }
    }
}
