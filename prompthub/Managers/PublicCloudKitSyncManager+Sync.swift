import CloudKit
import SwiftData

// MARK: - Sync & Cleanup

extension PublicCloudKitSyncManager {

    // MARK: - Delete (with local coordination)

    func deleteSharedCreation(_ sharedCreation: SharedCreation) async throws {
        guard let recordName = sharedCreation.publicRecordName else { return }
        logger.debug("Deleting SharedCreation with recordName: \(recordName)")

        let descriptor = FetchDescriptor<SharedCreation>(predicate: #Predicate { $0.publicRecordName == recordName })
        let localMatches: [SharedCreation]
        do {
            localMatches = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch local SharedCreation \(recordName): \(error.localizedDescription)")
            throw error
        }

        guard let local = localMatches.first else {
            logger.warning("No local SharedCreation for \(recordName). Deleting from CloudKit only.")
            try await deleteItemFromPublicCloud(recordName: recordName)
            return
        }

        do {
            try await deleteItemFromPublicCloud(recordName: recordName)
            logger.info("Deleted record \(recordName) from CloudKit.")
        } catch {
            logger.error("CloudKit delete failed for \(recordName): \(error.localizedDescription)")
            throw NSError(domain: "CloudKitSync", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Failed to delete from CloudKit. Local copy preserved for retry."
            ])
        }

        modelContext.delete(local)
        do {
            try modelContext.save()
            logger.info("Deleted SharedCreation \(local.name) from local store.")
        } catch {
            logger.error("Failed to save ModelContext after deleting \(local.name): \(error.localizedDescription)")
            throw error
        }
    }

    func canDeleteSharedCreation(recordName: String) -> Bool {
        let descriptor = FetchDescriptor<SharedCreation>(predicate: #Predicate { $0.publicRecordName == recordName })
        do {
            let local = try modelContext.fetch(descriptor)
            guard let creation = local.first else { return false }
            return SharedCreation.isCreatedByCurrentUser(id: creation.id, modelContext: modelContext)
        } catch {
            logger.error("Failed to fetch SharedCreation \(recordName): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Fetch All

    func fetchAllPublicSharedCreations(limit: Int = 50) async throws -> [SharedCreation] {
        logger.debug("Fetching all public SharedCreations (limit: \(limit))")
        let query = CKQuery(recordType: CloudKitRecordType.sharedCreation, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]

        var results: [SharedCreation] = []
        let (matchResults, _) = try await publicDB.records(matching: query, desiredKeys: nil, resultsLimit: limit)
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                let creation = convertRecordToSharedCreation(record)
                results.append(creation)
            case .failure(let error):
                logger.error("Error in fetched result: \(error.localizedDescription)")
            }
        }
        logger.info("Fetched \(results.count) public SharedCreations.")
        return results
    }

    private func convertRecordToSharedCreation(_ record: CKRecord) -> SharedCreation {
        let cloudUUIDString = record[SharedCreationField.sharedCreationID] as? String
        let id = cloudUUIDString.flatMap { UUID(uuidString: $0) } ?? UUID()
        let creation = sharedCreationFromRecord(record, id: id)
        creation.dataSources     = dataSourcesFromRecord(record)
        creation.publicRecordName = record.recordID.recordName
        if let modDate = record.modificationDate { creation.lastModified = modDate }
        return creation
    }

    // MARK: - Cleanup

    func cleanupOrphanedLocalSharedCreations() async throws {
        logger.debug("Starting orphan cleanup.")
        let descriptor = FetchDescriptor<SharedCreation>(predicate: #Predicate { $0.publicRecordName != nil })
        let local: [SharedCreation]
        do {
            local = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch local SharedCreations: \(error.localizedDescription)")
            throw error
        }
        logger.info("Checking \(local.count) local SharedCreations with publicRecordName.")

        var deletedCount = 0
        for creation in local {
            guard let recordName = creation.publicRecordName else { continue }
            do {
                _ = try await publicDB.record(for: CKRecord.ID(recordName: recordName))
                logger.trace("Record \(recordName) still exists.")
            } catch let error as CKError where error.code == .unknownItem {
                logger.info("Record \(recordName) gone — removing local copy: \(creation.name)")
                modelContext.delete(creation)
                deletedCount += 1
            } catch {
                logger.warning("Error checking \(recordName): \(error.localizedDescription). Keeping local copy.")
            }
        }

        if deletedCount > 0 {
            do {
                try modelContext.save()
                logger.info("Cleaned up \(deletedCount) orphaned local SharedCreations.")
            } catch {
                logger.error("Failed to save after cleanup: \(error.localizedDescription)")
                throw error
            }
        } else {
            logger.info("No orphaned local SharedCreations found.")
        }
    }
}
