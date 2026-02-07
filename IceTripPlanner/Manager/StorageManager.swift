import Foundation
import Combine

class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    private let tripsKey = "saved_trips"
    private let settingsKey = "app_settings"
    
    @Published var trips: [Trip] = []
    @Published var settings: AppSettings = .default
    
    private init() {
        loadTrips()
        loadSettings()
    }
    
    // MARK: - Trip Operations
    func loadTrips() {
        if let data = UserDefaults.standard.data(forKey: tripsKey),
           let decoded = try? JSONDecoder().decode([Trip].self, from: data) {
            trips = decoded.sorted { $0.date < $1.date }
        }
    }
    
    func saveTrips() {
        if let encoded = try? JSONEncoder().encode(trips) {
            UserDefaults.standard.set(encoded, forKey: tripsKey)
        }
    }
    
    func addTrip(_ trip: Trip) {
        trips.append(trip)
        saveTrips()
    }
    
    func updateTrip(_ trip: Trip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            var updatedTrip = trip
            updatedTrip.updatedAt = Date()
            trips[index] = updatedTrip
            saveTrips()
        }
    }
    
    func deleteTrip(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        saveTrips()
    }
    
    func deleteTrips(at offsets: IndexSet) {
        trips.remove(atOffsets: offsets)
        saveTrips()
    }
    
    // MARK: - Settings Operations
    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveSettings()
    }
    
    func resetAllData() {
        trips.removeAll()
        settings = .default
        UserDefaults.standard.removeObject(forKey: tripsKey)
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }
    
    // MARK: - Statistics
    func getTripStatistics() -> TripStatistics {
        let total = trips.count
        let completed = trips.filter { $0.status == .completed }.count
        let completionRate = total > 0 ? Double(completed) / Double(total) * 100 : 0
        
        let completedTrips = trips.filter { $0.status == .completed }
        let avgBiteScore = completedTrips.compactMap { $0.result?.biteScore }.reduce(0, +) / max(completedTrips.count, 1)
        
        // Find best month
        let monthCounts = Dictionary(grouping: completedTrips) { trip in
            Calendar.current.component(.month, from: trip.date)
        }.mapValues { $0.count }
        
        let bestMonth = monthCounts.max { $0.value < $1.value }?.key ?? 1
        let monthName = Calendar.current.monthSymbols[bestMonth - 1]
        
        return TripStatistics(
            totalTrips: total,
            completedTrips: completed,
            completionRate: completionRate,
            avgBiteScore: avgBiteScore,
            bestMonth: monthName
        )
    }
}

// MARK: - Trip Statistics
struct TripStatistics {
    let totalTrips: Int
    let completedTrips: Int
    let completionRate: Double
    let avgBiteScore: Int
    let bestMonth: String
}
