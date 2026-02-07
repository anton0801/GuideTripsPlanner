import SwiftUI

struct TripsListView: View {
    @StateObject private var viewModel = TripViewModel()
    @State private var selectedFilter: TripFilter = .upcoming
    @State private var showingAddTrip = false
    @State private var searchText = ""
    
    enum TripFilter: String, CaseIterable {
        case upcoming = "Upcoming"
        case past = "Past"
        case all = "All"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "F0F8FF"),
                        Color(hex: "E6F3FF")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Picker
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(TripFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hex: "1E3A5F").opacity(0.5))
                        
                        TextField("Search trips...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    // Trips List
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(filteredTrips) { trip in
                                NavigationLink(destination: TripDetailView(trip: trip)) {
                                    TripCardView(trip: trip)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            if filteredTrips.isEmpty {
                                EmptyStateView(
                                    icon: "tray",
                                    title: "No Trips Found",
                                    description: selectedFilter == .upcoming
                                        ? "Plan your next fishing adventure"
                                        : "No trips match your filter"
                                )
                                .padding(.top, 50)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("All Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTrip = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(hex: "4A90E2"))
                    }
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                AddTripView()
            }
        }
    }
    
    private var filteredTrips: [Trip] {
        var trips: [Trip] = []
        
        switch selectedFilter {
        case .upcoming:
            trips = viewModel.upcomingTrips()
        case .past:
            trips = viewModel.pastTrips()
        case .all:
            trips = viewModel.trips.sorted { $0.date > $1.date }
        }
        
        if !searchText.isEmpty {
            trips = trips.filter { trip in
                trip.name.localizedCaseInsensitiveContains(searchText) ||
                trip.placeName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return trips
    }
}
