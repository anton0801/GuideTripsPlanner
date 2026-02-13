import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                mainTabView
            }
        }
    }
    
    @State private var lastShownToastId: String = ""
    @State private var newlyUnlocked:    Achievement? = nil
    
    var mainTabView: some View {
        ZStack {
            
            TabView(selection: $selectedTab) {
                CalendarView()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }
                    .tag(0)
                
                TripsListView()
                    .tabItem {
                        Label("Trips", systemImage: "list.bullet")
                    }
                    .tag(1)
                
                //            StatisticsView()
                //                .tabItem {
                //                    Label("Stats", systemImage: "chart.bar.fill")
                //                }
                //                .tag(2)
                AnalyticsView()
                    .tabItem { Label("Analytics", systemImage: "chart.xyaxis.line") }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)
            }
            .accentColor(Color(hex: "4A90E2"))
            
            if let badge = newlyUnlocked {
                AchievementUnlockToast(achievement: badge)
                    .padding(.top, 8)
                    .zIndex(999)
            }
        }
        .onReceive(AchievementEngine.shared.$achievements) { all in
            // Find the most recently unlocked one from today
            let fresh = all
                .filter { $0.isUnlocked }
                .filter { Calendar.current.isDateInToday($0.unlockedDate ?? .distantPast) }
                .sorted { ($0.unlockedDate ?? .distantPast) > ($1.unlockedDate ?? .distantPast) }
            
            if let latest = fresh.first, latest.id != lastShownToastId {
                lastShownToastId = latest.id
                withAnimation { newlyUnlocked = latest }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
                    withAnimation { newlyUnlocked = nil }
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(hex: "4A90E2").opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "4A90E2"))
            }
            
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "1E3A5F"))
            
            Text(description)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .onAppear {
            isAnimating = true
        }
    }
}
