import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = TripViewModel()
    @State private var selectedDate = Date()
    @State private var showingAddTrip = false
    @State private var calendarMode: CalendarMode = .month
    
    enum CalendarMode {
        case month, list
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
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
                    // Mode Picker
                    Picker("View Mode", selection: $calendarMode) {
                        Text("Month").tag(CalendarMode.month)
                        Text("List").tag(CalendarMode.list)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if calendarMode == .month {
                        MonthCalendarView(
                            selectedDate: $selectedDate,
                            trips: viewModel.trips
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: 15) {
                                ForEach(viewModel.upcomingTrips()) { trip in
                                    NavigationLink(destination: TripDetailView(trip: trip)) {
                                        TripCardView(trip: trip)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                if viewModel.upcomingTrips().isEmpty {
                                    EmptyStateView(
                                        icon: "calendar.badge.plus",
                                        title: "No Upcoming Trips",
                                        description: "Plan your first fishing trip"
                                    )
                                    .padding(.top, 50)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Trips")
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
}
