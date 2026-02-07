import SwiftUI

struct TripResultView: View {
    let trip: Trip
    @StateObject private var viewModel = TripViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var biteScore: Int = 3
    @State private var catchCount: String = "0"
    @State private var bestMoment: String = ""
    @State private var lessonsLearned: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trip Results")) {
                    // Bite Score
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bite Score")
                            .font(.system(size: 16, weight: .semibold))
                        
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { index in
                                Button(action: {
                                    withAnimation(.spring()) {
                                        biteScore = index
                                    }
                                }) {
                                    Image(systemName: index <= biteScore ? "star.fill" : "star")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color(hex: "FFB74D"))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Catch Count
                    HStack {
                        Text("Catch Count")
                        Spacer()
                        TextField("0", text: $catchCount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section(header: Text("Memories")) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Best Moment")
                            .font(.system(size: 14, weight: .semibold))
                        TextEditor(text: $bestMoment)
                            .frame(height: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Lessons Learned")
                            .font(.system(size: 14, weight: .semibold))
                        TextEditor(text: $lessonsLearned)
                            .frame(height: 80)
                    }
                }
            }
            .navigationTitle("Trip Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveResult()
                    }
                }
            }
        }
    }
    
    private func saveResult() {
        let result = TripResult(
            biteScore: biteScore,
            catchCount: Int(catchCount) ?? 0,
            bestMoment: bestMoment,
            lessonsLearned: lessonsLearned,
            completedDate: Date()
        )
        
        viewModel.updateTripResult(tripId: trip.id, result: result)
        presentationMode.wrappedValue.dismiss()
    }
}
