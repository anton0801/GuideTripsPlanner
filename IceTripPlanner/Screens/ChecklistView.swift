import SwiftUI

struct ChecklistView: View {
    let trip: Trip
    @StateObject private var viewModel = TripViewModel()
    @State private var showingAddItem = false
    @State private var selectedCategory: ChecklistCategory?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress Card
                progressCard
                
                // Categories
                ForEach(ChecklistCategory.allCases, id: \.self) { category in
                    categorySection(category: category)
                }
                
                // Add Item Button
                Button(action: { showingAddItem = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Custom Item")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "4A90E2"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "4A90E2").opacity(0.1))
                    .cornerRadius(15)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
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
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddItem) {
            AddChecklistItemView(trip: trip)
        }
    }
    
    private var progressCard: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Overall Progress")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1E3A5F"))
                    
                    Text("\(completedCount) of \(totalCount) items")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color(hex: "4A90E2").opacity(0.2), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(trip.checklistProgress))
                        .stroke(
                            Color(hex: "4CAF50"),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: trip.checklistProgress)
                    
                    Text("\(Int(trip.checklistProgress * 100))%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "4CAF50"))
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
        .padding(.horizontal)
    }
    
    private func categorySection(category: ChecklistCategory) -> some View {
        let items = trip.checklistItems.filter { $0.category == category }
        
        return VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(Color(hex: category.color))
                Text(category.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "1E3A5F"))
                
                Spacer()
                
                Text("\(items.filter { $0.isCompleted }.count)/\(items.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
            }
            
            if items.isEmpty {
                Text("No items in this category")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "1E3A5F").opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        ChecklistItemRow(
                            item: item,
                            onToggle: {
                                withAnimation(.spring()) {
                                    viewModel.toggleChecklistItem(
                                        tripId: trip.id,
                                        itemId: item.id
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
        .padding(.horizontal)
    }
    
    private var completedCount: Int {
        trip.checklistItems.filter { $0.isCompleted }.count
    }
    
    private var totalCount: Int {
        trip.checklistItems.count
    }
}

// MARK: - Checklist Item Row
struct ChecklistItemRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onToggle()
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: item.category.color).opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if item.isCompleted {
                        Circle()
                            .fill(Color(hex: item.category.color))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3), value: isPressed)
                
                Text(item.name)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "1E3A5F"))
                    .strikethrough(item.isCompleted)
                    .opacity(item.isCompleted ? 0.6 : 1.0)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Add Checklist Item View
struct AddChecklistItemView: View {
    let trip: Trip
    @StateObject private var viewModel = TripViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var itemName = ""
    @State private var selectedCategory: ChecklistCategory = .gear
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $itemName)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ChecklistCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(itemName.isEmpty)
                }
            }
        }
    }
    
    private func addItem() {
        var updatedTrip = trip
        let newItem = ChecklistItem(
            name: itemName,
            category: selectedCategory
        )
        updatedTrip.checklistItems.append(newItem)
        viewModel.updateTrip(updatedTrip)
        presentationMode.wrappedValue.dismiss()
    }
}
