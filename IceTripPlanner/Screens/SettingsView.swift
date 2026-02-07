import SwiftUI

struct SettingsView: View {
    @StateObject private var storageManager = StorageManager.shared
    @State private var showingResetAlert = false
    @State private var selectedSeason: Season
    @State private var selectedWeekStart: Int
    
    init() {
        let settings = StorageManager.shared.settings
        _selectedSeason = State(initialValue: settings.defaultSeason)
        _selectedWeekStart = State(initialValue: settings.weekStartDay)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Preferences")) {
                    Picker("Default Season", selection: $selectedSeason) {
                        ForEach(Season.allCases, id: \.self) { season in
                            HStack {
                                Image(systemName: season.icon)
                                Text(season.rawValue)
                            }
                            .tag(season)
                        }
                    }
                    .onChange(of: selectedSeason) { newValue in
                        var settings = storageManager.settings
                        settings.defaultSeason = newValue
                        storageManager.updateSettings(settings)
                    }
                    
                    Picker("Week Starts On", selection: $selectedWeekStart) {
                        Text("Sunday").tag(0)
                        Text("Monday").tag(1)
                    }
                    .onChange(of: selectedWeekStart) { newValue in
                        var settings = storageManager.settings
                        settings.weekStartDay = newValue
                        storageManager.updateSettings(settings)
                    }
                }
                
                Section(header: Text("Data")) {
                    Button(action: { showingResetAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Reset All Data")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Trips")
                        Spacer()
                        Text("\(storageManager.trips.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
//                Section {
//                    Link(destination: URL(string: "https://example.com/privacy")!) {
//                        HStack {
//                            Image(systemName: "hand.raised")
//                            Text("Privacy Policy")
//                        }
//                    }
//                    
//                    Link(destination: URL(string: "https://example.com/terms")!) {
//                        HStack {
//                            Image(systemName: "doc.text")
//                            Text("Terms of Service")
//                        }
//                    }
//                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Reset All Data", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    storageManager.resetAllData()
                }
            } message: {
                Text("This will delete all your trips and data. This action cannot be undone.")
            }
        }
    }
}
