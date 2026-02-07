import SwiftUI

struct EditTripView: View {
    let trip: Trip
    @StateObject private var viewModel = TripViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tripName: String
    @State private var selectedDate: Date
    @State private var selectedSeason: Season
    @State private var placeName: String
    @State private var selectedStatus: TripStatus
    @State private var notes: String
    
    init(trip: Trip) {
        self.trip = trip
        _tripName = State(initialValue: trip.name)
        _selectedDate = State(initialValue: trip.date)
        _selectedSeason = State(initialValue: trip.season)
        _placeName = State(initialValue: trip.placeName)
        _selectedStatus = State(initialValue: trip.status)
        _notes = State(initialValue: trip.notes)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trip Details")) {
                    TextField("Trip Name", text: $tripName)
                    
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    Picker("Season", selection: $selectedSeason) {
                        ForEach(Season.allCases, id: \.self) { season in
                            HStack {
                                Image(systemName: season.icon)
                                Text(season.rawValue)
                            }
                            .tag(season)
                        }
                    }
                    
                    TextField("Place Name", text: $placeName)
                    
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(TripStatus.allCases, id: \.self) { status in
                            HStack {
                                Image(systemName: status.icon)
                                Text(status.rawValue)
                            }
                            .tag(status)
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 120)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTrip()
                    }
                    .disabled(tripName.isEmpty || placeName.isEmpty)
                }
            }
        }
    }
    
    private func saveTrip() {
        var updatedTrip = trip
        updatedTrip.name = tripName
        updatedTrip.date = selectedDate
        updatedTrip.season = selectedSeason
        updatedTrip.placeName = placeName
        updatedTrip.status = selectedStatus
        updatedTrip.notes = notes
        
        viewModel.updateTrip(updatedTrip)
        presentationMode.wrappedValue.dismiss()
    }
}
