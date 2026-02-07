import Foundation
import Combine

class TripViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var selectedTrip: Trip?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var storageManager = StorageManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        storageManager.$trips
            .assign(to: &$trips)
    }
    
    // MARK: - Trip Management
    func createTrip(
        name: String,
        date: Date,
        season: Season,
        placeName: String,
        notes: String = ""
    ) {
        let checklistItems = season == .ice
            ? ChecklistPreset.iceFishingItems
            : ChecklistPreset.summerFishingItems
        
        let trip = Trip(
            name: name,
            date: date,
            season: season,
            placeName: placeName,
            notes: notes,
            checklistItems: checklistItems
        )
        
        storageManager.addTrip(trip)
    }
    
    func updateTrip(_ trip: Trip) {
        storageManager.updateTrip(trip)
    }
    
    func deleteTrip(_ trip: Trip) {
        storageManager.deleteTrip(trip)
    }
    
    func toggleChecklistItem(tripId: UUID, itemId: UUID) {
        guard var trip = trips.first(where: { $0.id == tripId }),
              let index = trip.checklistItems.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        
        trip.checklistItems[index].isCompleted.toggle()
        updateTrip(trip)
    }
    
    func addTask(to tripId: UUID, task: TripTask) {
        guard var trip = trips.first(where: { $0.id == tripId }) else { return }
        trip.tasks.append(task)
        updateTrip(trip)
    }
    
    func toggleTask(tripId: UUID, taskId: UUID) {
        guard var trip = trips.first(where: { $0.id == tripId }),
              let index = trip.tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        
        trip.tasks[index].isCompleted.toggle()
        trip.tasks[index].completedAt = trip.tasks[index].isCompleted ? Date() : nil
        updateTrip(trip)
    }
    
    func updateTripResult(tripId: UUID, result: TripResult) {
        guard var trip = trips.first(where: { $0.id == tripId }) else { return }
        trip.result = result
        trip.status = .completed
        updateTrip(trip)
    }
    
    // MARK: - Filtering & Sorting
    func upcomingTrips() -> [Trip] {
        trips.filter { $0.date >= Date() && $0.status == .planned }
            .sorted { $0.date < $1.date }
    }
    
    func pastTrips() -> [Trip] {
        trips.filter { $0.date < Date() || $0.status != .planned }
            .sorted { $0.date > $1.date }
    }
    
    func tripsByStatus(_ status: TripStatus) -> [Trip] {
        trips.filter { $0.status == status }
    }
    
    func tripsBySeason(_ season: Season) -> [Trip] {
        trips.filter { $0.season == season }
    }
    
    func tripsForMonth(_ date: Date) -> [Trip] {
        let calendar = Calendar.current
        return trips.filter { trip in
            calendar.isDate(trip.date, equalTo: date, toGranularity: .month)
        }
    }
}
