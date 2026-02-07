import SwiftUI

struct AddTripView: View {
    @StateObject private var viewModel = TripViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tripName = ""
    @State private var selectedDate = Date()
    @State private var selectedSeason: Season = .ice
    @State private var placeName = ""
    @State private var notes = ""
    
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
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("New Trip")
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
        viewModel.createTrip(
            name: tripName,
            date: selectedDate,
            season: selectedSeason,
            placeName: placeName,
            notes: notes
        )
        presentationMode.wrappedValue.dismiss()
    }
}
