import SwiftUI

struct TripCardView: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "1E3A5F"))
                    
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(trip.placeName)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: trip.season.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: trip.season.color))
            }
            
            HStack {
                Label(
                    formattedDate,
                    systemImage: "calendar"
                )
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "1E3A5F").opacity(0.8))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: trip.status.icon)
                    Text(trip.status.rawValue)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: trip.status.color))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: trip.status.color).opacity(0.15))
                .cornerRadius(12)
            }
            
            // Progress bars
            if !trip.checklistItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .font(.caption)
                        Text("Checklist")
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(Int(trip.checklistProgress * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                    
                    ProgressView(value: trip.checklistProgress)
                        .tint(Color(hex: "4CAF50"))
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: trip.date)
    }
}
