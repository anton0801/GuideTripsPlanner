import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    @StateObject private var viewModel = TripViewModel()
    @State private var showingEditSheet = false
    @State private var showingResultSheet = false
    @State private var showingDeleteAlert = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Section
                headerSection
                
                // Checklist Preview
                checklistSection
                
                // Tasks Section
                tasksSection
                
                // Notes Section
                if !trip.notes.isEmpty {
                    notesSection
                }
                
                // Result Section
                if let result = trip.result {
                    resultSection(result: result)
                }
                
                // Action Buttons
                actionButtons
            }
            .padding()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "F0F8FF"),
                    Color(hex: "E6F3FF")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label("Edit Trip", systemImage: "pencil")
                    }
                    
                    if trip.status == .planned {
                        Button(action: { showingResultSheet = true }) {
                            Label("Add Result", systemImage: "checkmark.circle")
                        }
                    }
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete Trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTripView(trip: trip)
        }
        .sheet(isPresented: $showingResultSheet) {
            TripResultView(trip: trip)
        }
        .alert("Delete Trip", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteTrip(trip)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this trip? This action cannot be undone.")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: trip.season.icon)
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: trip.season.color))
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    HStack {
                        Image(systemName: trip.status.icon)
                        Text(trip.status.rawValue)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: trip.status.color))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(Color(hex: trip.status.color).opacity(0.15))
                    .cornerRadius(15)
                    
                    Text(trip.season.rawValue)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "calendar")
                    Text(formattedDate)
                }
                
                HStack {
                    Image(systemName: "mappin.circle.fill")
                    Text(trip.placeName)
                }
            }
            .font(.system(size: 16))
            .foregroundColor(Color(hex: "1E3A5F"))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }
    
    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("Checklist", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "1E3A5F"))
                
                Spacer()
                
                NavigationLink(destination: ChecklistView(trip: trip)) {
                    Text("View All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "4A90E2"))
                }
            }
            
            // Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(trip.checklistProgress * 100))% Complete")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "1E3A5F"))
                    
                    Spacer()
                    
                    Text("\(trip.checklistItems.filter { $0.isCompleted }.count)/\(trip.checklistItems.count)")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                }
                
                ProgressView(value: trip.checklistProgress)
                    .tint(Color(hex: "4CAF50"))
                    .scaleEffect(y: 2)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }
    
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("Tasks", systemImage: "list.bullet.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "1E3A5F"))
                
                Spacer()
                
                NavigationLink(destination: TasksView(trip: trip)) {
                    Text(trip.tasks.isEmpty ? "Add Tasks" : "View All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "4A90E2"))
                }
            }
            
            if !trip.tasks.isEmpty {
                VStack(spacing: 10) {
                    ForEach(trip.tasks.prefix(3)) { task in
                        TaskRowView(task: task, isCompact: true)
                    }
                }
            } else {
                Text("No tasks yet")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "1E3A5F").opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Notes", systemImage: "note.text")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "1E3A5F"))
            
            Text(trip.notes)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "1E3A5F").opacity(0.8))
                .lineSpacing(4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }
    
    private func resultSection(result: TripResult) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Trip Result", systemImage: "star.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "1E3A5F"))
            
            HStack(spacing: 20) {
                VStack {
                    Text("Bite Score")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= result.biteScore ? "star.fill" : "star")
                                .foregroundColor(Color(hex: "FFB74D"))
                        }
                    }
                }
                
                Divider()
                
                VStack {
                    Text("Catch Count")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                    
                    Text("\(result.catchCount)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "4CAF50"))
                }
            }
            .frame(maxWidth: .infinity)
            
            if !result.bestMoment.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Best Moment")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "1E3A5F"))
                    
                    Text(result.bestMoment)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "1E3A5F").opacity(0.8))
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 15) {
            if trip.status == .planned {
                Button(action: { showingResultSheet = true }) {
                    Label("Complete Trip", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "4CAF50"))
                        .cornerRadius(15)
                }
            }
            
            Button(action: { showingEditSheet = true }) {
                Label("Edit", systemImage: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "4A90E2"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "4A90E2").opacity(0.15))
                    .cornerRadius(15)
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: trip.date)
    }
}
