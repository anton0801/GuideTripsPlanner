
import SwiftUI

#Preview {
    StatisticsView()
}

struct StatisticsView: View {
    @StateObject private var storageManager = StorageManager.shared
    
    var statistics: TripStatistics {
        storageManager.getTripStatistics()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Overview Cards
                    overviewSection
                    
                    // Completion Rate
                    completionRateCard
                    
                    // Season Breakdown
                    seasonBreakdownCard
                    
                    // Best Month
                    bestMonthCard
                    
                    // Recent Activity
                    recentActivityCard
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
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var overviewSection: some View {
        HStack(spacing: 15) {
            StatCard(
                icon: "calendar.badge.clock",
                value: "\(statistics.totalTrips)",
                label: "Total Trips",
                color: "4A90E2"
            )
            
            StatCard(
                icon: "checkmark.circle.fill",
                value: "\(statistics.completedTrips)",
                label: "Completed",
                color: "4CAF50"
            )
        }
    }
    
    private var completionRateCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Completion Rate", systemImage: "chart.bar.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "1E3A5F"))
            
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "4A90E2").opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(statistics.completionRate / 100))
                        .stroke(
                            Color(hex: "4CAF50"),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 4) {
                        Text("\(Int(statistics.completionRate))%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "4CAF50"))
                        
                        Text("Complete")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(
                        label: "Completed",
                        value: "\(statistics.completedTrips)",
                        color: "4CAF50"
                    )
                    
                    StatRow(
                        label: "Pending",
                        value: "\(statistics.totalTrips - statistics.completedTrips)",
                        color: "FF9800"
                    )
                    
                    StatRow(
                        label: "Avg Bite Score",
                        value: "\(statistics.avgBiteScore)/5",
                        color: "FFB74D"
                    )
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }
    
    private var seasonBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Season Breakdown", systemImage: "snowflake")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "1E3A5F"))
            
            HStack(spacing: 20) {
                SeasonBar(
                    season: .ice,
                    count: storageManager.trips.filter { $0.season == .ice }.count,
                    total: statistics.totalTrips
                )
                
                SeasonBar(
                    season: .summer,
                    count: storageManager.trips.filter { $0.season == .summer }.count,
                    total: statistics.totalTrips
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }
    
    private var bestMonthCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Best Month", systemImage: "star.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "1E3A5F"))
            
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "FFB74D"))
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    Text(statistics.bestMonth)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "1E3A5F"))
                    
                    Text("Most successful trips")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }
    
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Recent Activity", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "1E3A5F"))
            
            if storageManager.trips.isEmpty {
                Text("No activity yet")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "1E3A5F").opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(storageManager.trips.sorted { $0.updatedAt > $1.updatedAt }.prefix(5)) { trip in
                        HStack {
                            Image(systemName: trip.season.icon)
                                .foregroundColor(Color(hex: trip.season.color))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "1E3A5F"))
                                
                                Text(relativeDateString(trip.updatedAt))
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "1E3A5F").opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Image(systemName: trip.status.icon)
                                .foregroundColor(Color(hex: trip.status.color))
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }
    
    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(Color(hex: color))
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(hex: "1E3A5F"))
            
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let label: String
    let value: String
    let color: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "1E3A5F"))
        }
    }
}

// MARK: - Season Bar
struct SeasonBar: View {
    let season: Season
    let count: Int
    let total: Int
    
    var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: season.icon)
                .font(.system(size: 30))
                .foregroundColor(Color(hex: season.color))
            
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: season.color).opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: season.color))
                        .frame(height: geometry.size.height * CGFloat(percentage))
                }
            }
            .frame(height: 100)
            
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "1E3A5F"))
            
            Text(season.rawValue)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}
