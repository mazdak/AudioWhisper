import Foundation
import SwiftData
import os.log

enum DataManagerError: Error, LocalizedError {
    case initializationFailed(Error)
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case cleanupFailed(Error)
    case modelContainerUnavailable
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Failed to initialize data storage: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save transcription record: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch transcription records: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete transcription record: \(error.localizedDescription)"
        case .cleanupFailed(let error):
            return "Failed to clean up old records: \(error.localizedDescription)"
        case .modelContainerUnavailable:
            return "Data storage is not available"
        }
    }
}

enum RetentionPeriod: String, CaseIterable, Codable {
    case oneWeek = "oneWeek"
    case oneMonth = "oneMonth"
    case threeMonths = "threeMonths"
    case forever = "forever"
    
    var displayName: String {
        switch self {
        case .oneWeek:
            return "1 Week"
        case .oneMonth:
            return "1 Month"
        case .threeMonths:
            return "3 Months"
        case .forever:
            return "Forever"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .oneWeek:
            return 7 * 24 * 60 * 60 // 7 days in seconds
        case .oneMonth:
            return 30 * 24 * 60 * 60 // 30 days in seconds
        case .threeMonths:
            return 90 * 24 * 60 * 60 // 90 days in seconds
        case .forever:
            return nil
        }
    }
}

@MainActor
protocol DataManagerProtocol {
    var isHistoryEnabled: Bool { get }
    var retentionPeriod: RetentionPeriod { get set }
    var sharedModelContainer: ModelContainer? { get }
    
    func initialize() throws
    func saveTranscription(_ record: TranscriptionRecord) async throws
    func fetchAllRecords() async throws -> [TranscriptionRecord]
    func fetchRecords(matching searchQuery: String) async throws -> [TranscriptionRecord]
    func fetchRecords(matching searchQuery: String, limit: Int?, offset: Int?) async throws -> [TranscriptionRecord]
    func deleteRecord(_ record: TranscriptionRecord) async throws
    func deleteAllRecords() async throws
    func cleanupExpiredRecords() async throws
    
    // Backward compatibility methods that don't throw
    func saveTranscriptionQuietly(_ record: TranscriptionRecord) async
    func fetchAllRecordsQuietly() async -> [TranscriptionRecord]
    func cleanupExpiredRecordsQuietly() async
}

@MainActor
final class DataManager: DataManagerProtocol {
    nonisolated(unsafe) static let shared: DataManagerProtocol = MainActor.assumeIsolated {
        DataManager()
    }
    
    private var modelContainer: ModelContainer?
    
    /// Public accessor for the model container, primarily for SwiftUI integration
    var sharedModelContainer: ModelContainer? {
        return modelContainer
    }
    
    var isHistoryEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "transcriptionHistoryEnabled")
    }
    
    var retentionPeriod: RetentionPeriod {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "transcriptionRetentionPeriod") ?? RetentionPeriod.oneMonth.rawValue
            return RetentionPeriod(rawValue: rawValue) ?? .oneMonth
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "transcriptionRetentionPeriod")
        }
    }
    
    private init() {}
    
    func initialize() throws {
        do {
            let schema = Schema([
                TranscriptionRecord.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            Logger.dataManager.info("DataManager initialized successfully")
            
            // Perform initial cleanup of expired records
            Task {
                await cleanupExpiredRecordsQuietly()
            }
            
        } catch {
            Logger.dataManager.error("Failed to initialize DataManager: \(error.localizedDescription)")
            throw DataManagerError.initializationFailed(error)
        }
    }
    
    func saveTranscription(_ record: TranscriptionRecord) async throws {
        guard isHistoryEnabled else {
            Logger.dataManager.debug("Transcription history is disabled, skipping save")
            return
        }
        
        guard let container = modelContainer else {
            throw DataManagerError.modelContainerUnavailable
        }
        
        do {
            let context = ModelContext(container)
            context.insert(record)
            try context.save()
            
            Logger.dataManager.info("Saved transcription record with ID: \(record.id)")
            
            // Perform cleanup after save to maintain retention policy
            await cleanupExpiredRecordsQuietly()
            
        } catch {
            Logger.dataManager.error("Failed to save transcription record: \(error.localizedDescription)")
            throw DataManagerError.saveFailed(error)
        }
    }
    
    func fetchAllRecords() async throws -> [TranscriptionRecord] {
        guard let container = modelContainer else {
            throw DataManagerError.modelContainerUnavailable
        }
        
        do {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<TranscriptionRecord>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let records = try context.fetch(descriptor)
            
            Logger.dataManager.debug("Fetched \(records.count) transcription records")
            return records
            
        } catch {
            Logger.dataManager.error("Failed to fetch transcription records: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }
    
    func fetchRecords(matching searchQuery: String) async throws -> [TranscriptionRecord] {
        // Backward compatibility - calls the new method with no pagination
        return try await fetchRecords(matching: searchQuery, limit: nil, offset: nil)
    }
    
    func fetchRecords(matching searchQuery: String, limit: Int? = nil, offset: Int? = nil) async throws -> [TranscriptionRecord] {
        guard let container = modelContainer else {
            throw DataManagerError.modelContainerUnavailable
        }
        
        do {
            let context = ModelContext(container)
            var descriptor: FetchDescriptor<TranscriptionRecord>
            
            if searchQuery.isEmpty {
                // If no search query, return all records
                descriptor = FetchDescriptor<TranscriptionRecord>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                // Use SwiftData predicate for database-level filtering
                let lowercaseQuery = searchQuery.lowercased()
                let predicate = #Predicate<TranscriptionRecord> { record in
                    record.text.localizedStandardContains(lowercaseQuery) ||
                    record.provider.localizedStandardContains(lowercaseQuery) ||
                    (record.modelUsed != nil && record.modelUsed!.localizedStandardContains(lowercaseQuery))
                }
                
                descriptor = FetchDescriptor<TranscriptionRecord>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
            
            // Apply pagination if specified
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            if let offset = offset {
                descriptor.fetchOffset = offset
            }
            
            let records = try context.fetch(descriptor)
            
            Logger.dataManager.debug("Fetched \(records.count) records matching query: '\(searchQuery)' (limit: \(limit ?? -1), offset: \(offset ?? 0))")
            return records
            
        } catch {
            Logger.dataManager.error("Failed to fetch transcription records: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }
    
    func deleteRecord(_ record: TranscriptionRecord) async throws {
        guard let container = modelContainer else {
            throw DataManagerError.modelContainerUnavailable
        }
        
        do {
            let context = ModelContext(container)
            
            // Find the record in the context by fetching all and filtering
            let allRecords = try context.fetch(FetchDescriptor<TranscriptionRecord>())
            guard let recordToDelete = allRecords.first(where: { $0.id == record.id }) else {
                Logger.dataManager.warning("Record with ID \(record.id) not found for deletion")
                return
            }
            
            context.delete(recordToDelete)
            try context.save()
            
            Logger.dataManager.info("Deleted transcription record with ID: \(record.id)")
            
        } catch {
            Logger.dataManager.error("Failed to delete transcription record: \(error.localizedDescription)")
            throw DataManagerError.deleteFailed(error)
        }
    }
    
    func deleteAllRecords() async throws {
        guard let container = modelContainer else {
            throw DataManagerError.modelContainerUnavailable
        }
        
        do {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<TranscriptionRecord>()
            let records = try context.fetch(descriptor)
            
            for record in records {
                context.delete(record)
            }
            
            try context.save()
            
            Logger.dataManager.info("Deleted all \(records.count) transcription records")
            
        } catch {
            Logger.dataManager.error("Failed to delete all transcription records: \(error.localizedDescription)")
            throw DataManagerError.deleteFailed(error)
        }
    }
    
    func cleanupExpiredRecords() async throws {
        guard let timeInterval = retentionPeriod.timeInterval else {
            Logger.dataManager.debug("Retention period is forever, no cleanup needed")
            return
        }
        
        guard let container = modelContainer else {
            throw DataManagerError.modelContainerUnavailable
        }
        
        do {
            let context = ModelContext(container)
            let cutoffDate = Date().addingTimeInterval(-timeInterval)
            
            // Use SwiftData predicate for database-level filtering
            let predicate = #Predicate<TranscriptionRecord> { record in
                record.date < cutoffDate
            }
            
            let descriptor = FetchDescriptor<TranscriptionRecord>(predicate: predicate)
            let expiredRecords = try context.fetch(descriptor)
            
            for record in expiredRecords {
                context.delete(record)
            }
            
            try context.save()
            
            if !expiredRecords.isEmpty {
                Logger.dataManager.info("Cleaned up \(expiredRecords.count) expired transcription records")
            }
            
        } catch {
            Logger.dataManager.error("Failed to cleanup expired records: \(error.localizedDescription)")
            throw DataManagerError.cleanupFailed(error)
        }
    }
    
    // MARK: - Backward Compatibility Methods
    
    func saveTranscriptionQuietly(_ record: TranscriptionRecord) async {
        do {
            try await saveTranscription(record)
        } catch {
            Logger.dataManager.error("DataManager operation failed: \(error.localizedDescription)")
        }
    }
    
    func fetchAllRecordsQuietly() async -> [TranscriptionRecord] {
        do {
            return try await fetchAllRecords()
        } catch {
            Logger.dataManager.error("DataManager operation failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func cleanupExpiredRecordsQuietly() async {
        do {
            try await cleanupExpiredRecords()
        } catch {
            Logger.dataManager.error("DataManager operation failed: \(error.localizedDescription)")
        }
    }
}

// Mock implementation for testing
@MainActor
final class MockDataManager: DataManagerProtocol {
    private var records: [TranscriptionRecord] = []
    
    var isHistoryEnabled: Bool = true
    var retentionPeriod: RetentionPeriod = .oneMonth
    var sharedModelContainer: ModelContainer? = nil
    
    func initialize() throws {
        Logger.dataManager.info("Mock DataManager initialized")
    }
    
    func saveTranscription(_ record: TranscriptionRecord) async throws {
        guard isHistoryEnabled else { return }
        
        records.append(record)
        
        Logger.dataManager.info("Mock saved transcription record with ID: \(record.id)")
    }
    
    func fetchAllRecords() async throws -> [TranscriptionRecord] {
        return records.sorted { $0.date > $1.date }
    }
    
    func fetchRecords(matching searchQuery: String) async throws -> [TranscriptionRecord] {
        // Backward compatibility - calls the new method with no pagination
        return try await fetchRecords(matching: searchQuery, limit: nil, offset: nil)
    }
    
    func fetchRecords(matching searchQuery: String, limit: Int? = nil, offset: Int? = nil) async throws -> [TranscriptionRecord] {
        let allRecords = try await fetchAllRecords()
        let filteredRecords = allRecords.filter { $0.matches(searchQuery: searchQuery) }
        
        // Apply pagination if specified
        var results = filteredRecords
        if let offset = offset, offset < filteredRecords.count {
            results = Array(filteredRecords.dropFirst(offset))
        }
        if let limit = limit, limit > 0 {
            results = Array(results.prefix(limit))
        }
        
        Logger.dataManager.debug("Mock fetched \(results.count) records matching query: '\(searchQuery)' (limit: \(limit ?? -1), offset: \(offset ?? 0))")
        return results
    }
    
    func deleteRecord(_ record: TranscriptionRecord) async throws {
        records.removeAll { $0.id == record.id }
        
        Logger.dataManager.info("Mock deleted transcription record with ID: \(record.id)")
    }
    
    func deleteAllRecords() async throws {
        let count = records.count
        records.removeAll()
        Logger.dataManager.info("Mock deleted all \(count) transcription records")
    }
    
    func cleanupExpiredRecords() async throws {
        guard let timeInterval = retentionPeriod.timeInterval else { return }
        
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        let initialCount = records.count
        records.removeAll { $0.date < cutoffDate }
        let removedCount = initialCount - records.count
        
        if removedCount > 0 {
            Logger.dataManager.info("Mock cleaned up \(removedCount) expired transcription records")
        }
    }
    
    // MARK: - Backward Compatibility Methods
    
    func saveTranscriptionQuietly(_ record: TranscriptionRecord) async {
        do {
            try await saveTranscription(record)
        } catch {
            Logger.dataManager.error("Mock DataManager operation failed: \(error.localizedDescription)")
        }
    }
    
    func fetchAllRecordsQuietly() async -> [TranscriptionRecord] {
        do {
            return try await fetchAllRecords()
        } catch {
            Logger.dataManager.error("Mock DataManager operation failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func cleanupExpiredRecordsQuietly() async {
        do {
            try await cleanupExpiredRecords()
        } catch {
            Logger.dataManager.error("Mock DataManager operation failed: \(error.localizedDescription)")
        }
    }
}