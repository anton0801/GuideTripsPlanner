import SwiftUI
import Combine

struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String          // SF Symbol name
    let colorHex: String
    let tier: Tier
    var isUnlocked: Bool
    var unlockedDate: Date?
    var progress: Double      // 0.0 – 1.0
    var progressLabel: String // e.g. "3 / 5"

    enum Tier: String, Codable {
        case bronze, silver, gold

        var label: String {
            switch self {
            case .bronze: return "Bronze"
            case .silver: return "Silver"
            case .gold:   return "Gold"
            }
        }
        var colorHex: String {
            switch self {
            case .bronze: return "CD7F32"
            case .silver: return "A8A9AD"
            case .gold:   return "FFD700"
            }
        }
        var glow: Color {
            Color(hex: colorHex)
        }
    }
}

// MARK: ── Achievement Engine ────────────────────────────────

/// Evaluates all 19 achievements against the current trip list
/// and persists unlock state in UserDefaults.
class AchievementEngine: ObservableObject {
    static let shared = AchievementEngine()

    @Published var achievements: [Achievement] = []

    private let storageKey = "icetrip_achievements_v1"

    private init() { load() }

    // MARK: - Evaluate
    func evaluate(trips: [Trip]) {
        var updated = achievements
        for i in updated.indices {
            let (progress, label, unlocked) = compute(id: updated[i].id, trips: trips)
            updated[i].progress      = progress
            updated[i].progressLabel = label
            if unlocked && !updated[i].isUnlocked {
                updated[i].isUnlocked   = true
                updated[i].unlockedDate = Date()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        achievements = updated
        save()
    }

    // MARK: - Per-achievement logic
    private func compute(id: String, trips: [Trip]) -> (Double, String, Bool) {
        let completed         = trips.filter { $0.status == .completed }
        let iceTrips          = trips.filter { $0.season == .ice }
        let sumTrips          = trips.filter { $0.season == .summer }
        let allBites          = completed.compactMap { $0.result?.biteScore }
        let allCatch          = completed.compactMap { $0.result?.catchCount }
        let totalCatch        = allCatch.reduce(0, +)
        let perfectChecklists = completed.filter { $0.checklistProgress >= 1.0 }.count

        switch id {
        // Starter
        case "first_trip":
            let n = trips.count
            return (min(Double(n), 1), "\(n) / 1", n >= 1)
        case "triple":
            let n = trips.count
            return (min(Double(n)/3, 1), "\(n) / 3", n >= 3)
        case "ten_trips":
            let n = trips.count
            return (min(Double(n)/10, 1), "\(n) / 10", n >= 10)
        // Completion
        case "first_complete":
            let n = completed.count
            return (min(Double(n), 1), "\(n) / 1", n >= 1)
        case "five_complete":
            let n = completed.count
            return (min(Double(n)/5, 1), "\(n) / 5", n >= 5)
        case "twenty_complete":
            let n = completed.count
            return (min(Double(n)/20, 1), "\(n) / 20", n >= 20)
        // Bite Score
        case "perfect_bite":
            let fives = allBites.filter { $0 == 5 }.count
            return (min(Double(fives), 1), "\(fives) / 1", fives >= 1)
        case "five_perfect_bites":
            let fives = allBites.filter { $0 == 5 }.count
            return (min(Double(fives)/5, 1), "\(fives) / 5", fives >= 5)
        case "avg_bite_4":
            let avg = allBites.isEmpty ? 0.0 : Double(allBites.reduce(0,+)) / Double(allBites.count)
            return (min(avg/4.0, 1), String(format: "%.1f / 4.0", avg), avg >= 4.0)
        // Catch
        case "first_catch":
            return (totalCatch >= 1 ? 1 : 0, "\(totalCatch) / 1", totalCatch >= 1)
        case "catch_50":
            return (min(Double(totalCatch)/50, 1), "\(totalCatch) / 50", totalCatch >= 50)
        case "catch_200":
            return (min(Double(totalCatch)/200, 1), "\(totalCatch) / 200", totalCatch >= 200)
        case "big_haul":
            let best = allCatch.max() ?? 0
            return (min(Double(best)/10, 1), "\(best) / 10", best >= 10)
        // Seasons
        case "ice_master":
            let n = iceTrips.count
            return (min(Double(n)/10, 1), "\(n) / 10", n >= 10)
        case "summer_master":
            let n = sumTrips.count
            return (min(Double(n)/10, 1), "\(n) / 10", n >= 10)
        case "all_seasons":
            let hasIce = !iceTrips.isEmpty; let hasSummer = !sumTrips.isEmpty
            return ((hasIce ? 0.5 : 0) + (hasSummer ? 0.5 : 0),
                    "\(hasIce ? 1 : 0)+\(hasSummer ? 1 : 0) / 2 seasons",
                    hasIce && hasSummer)
        // Preparation
        case "perfect_checklist":
            return (perfectChecklists >= 1 ? 1 : 0, "\(perfectChecklists) / 1", perfectChecklists >= 1)
        case "five_perfect_checklists":
            return (min(Double(perfectChecklists)/5, 1), "\(perfectChecklists) / 5", perfectChecklists >= 5)
        // Streak
        case "monthly_trip":
            let months = Set(trips.map {
                Calendar.current.dateComponents([.year,.month], from: $0.date)
            }).count
            return (min(Double(months)/3, 1), "\(months) / 3 mo.", months >= 3)
        default:
            return (0, "–", false)
        }
    }

    // MARK: - Persistence
    private func save() {
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = decoded
        } else {
            achievements = AchievementEngine.catalog
        }
    }
    func reset() { achievements = AchievementEngine.catalog; save() }

    // MARK: - Catalog
    static var catalog: [Achievement] = [
        // Starter
        .init(id:"first_trip",              title:"First Trip",            description:"Add your very first fishing trip",                       icon:"flag.fill",                    colorHex:"4A90E2", tier:.bronze, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 1"),
        .init(id:"triple",                  title:"Hat Trick",             description:"Plan 3 trips",                                          icon:"3.circle.fill",                colorHex:"4A90E2", tier:.bronze, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 3"),
        .init(id:"ten_trips",               title:"Avid Angler",           description:"Log 10 trips in your journal",                          icon:"fish.fill",                    colorHex:"4CAF50", tier:.silver, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 10"),
        // Completion
        .init(id:"first_complete",          title:"Trip Done!",            description:"Mark your first trip as completed",                     icon:"checkmark.seal.fill",          colorHex:"4CAF50", tier:.bronze, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 1"),
        .init(id:"five_complete",           title:"Five For Five",         description:"Complete 5 trips",                                      icon:"star.circle.fill",             colorHex:"4CAF50", tier:.silver, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 5"),
        .init(id:"twenty_complete",         title:"Veteran",               description:"Complete 20 trips",                                     icon:"trophy.fill",                  colorHex:"FFD700", tier:.gold,   isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 20"),
        // Bite Score
        .init(id:"perfect_bite",            title:"They're Biting!",       description:"Score a perfect 5/5 bite rating",                       icon:"bolt.fill",                    colorHex:"FF9800", tier:.bronze, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 1"),
        .init(id:"five_perfect_bites",      title:"On Fire",               description:"Score 5/5 bite rating 5 times",                         icon:"bolt.circle.fill",             colorHex:"FF9800", tier:.silver, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 5"),
        .init(id:"avg_bite_4",              title:"Consistent Bites",      description:"Maintain average bite score ≥ 4.0",                     icon:"chart.line.uptrend.xyaxis",    colorHex:"FFD700", tier:.gold,   isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0.0 / 4.0"),
        // Catch
        .init(id:"first_catch",             title:"First Catch",           description:"Catch at least one fish",                               icon:"drop.fill",                    colorHex:"7CB9E8", tier:.bronze, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 1"),
        .init(id:"catch_50",                title:"Half Century",          description:"Reach a total catch of 50 fish",                        icon:"scalemass.fill",               colorHex:"4A90E2", tier:.silver, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 50"),
        .init(id:"catch_200",               title:"Commercial Fisher",     description:"Reach a total catch of 200 fish",                       icon:"cart.fill",                    colorHex:"FFD700", tier:.gold,   isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 200"),
        .init(id:"big_haul",                title:"Big Haul",              description:"Catch 10+ fish in a single trip",                       icon:"tray.full.fill",               colorHex:"4CAF50", tier:.silver, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 10"),
        // Seasons
        .init(id:"ice_master",              title:"Ice Master",            description:"Complete 10 ice fishing trips",                         icon:"snowflake",                    colorHex:"7CB9E8", tier:.gold,   isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 10"),
        .init(id:"summer_master",           title:"Summer Angler",         description:"Complete 10 summer fishing trips",                      icon:"sun.max.fill",                 colorHex:"FFB74D", tier:.gold,   isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 10"),
        .init(id:"all_seasons",             title:"All-Season Fisher",     description:"Fish in both ice and summer seasons",                   icon:"cloud.sun.fill",               colorHex:"9C27B0", tier:.silver, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0+0 / 2 seasons"),
        // Preparation
        .init(id:"perfect_checklist",       title:"Fully Prepared",        description:"Complete 100% of a checklist before a trip",            icon:"checkmark.rectangle.fill",     colorHex:"4CAF50", tier:.bronze, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 1"),
        .init(id:"five_perfect_checklists", title:"Methodical",            description:"Complete 5 trips with a perfect checklist",             icon:"list.bullet.clipboard.fill",   colorHex:"4CAF50", tier:.silver, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 5"),
        // Streak
        .init(id:"monthly_trip",            title:"Consistent",            description:"Log trips across 3 different months",                   icon:"calendar.badge.checkmark",     colorHex:"9C27B0", tier:.silver, isUnlocked:false, unlockedDate:nil, progress:0, progressLabel:"0 / 3 mo."),
    ]
}

#Preview {
    AchievementsView()
}

struct AchievementsView: View {
    @StateObject private var engine  = AchievementEngine.shared
    @StateObject private var storage = StorageManager.shared

    @State private var filter: FilterOption       = .all
    @State private var selected: Achievement?
    @State private var headerScale:   CGFloat     = 0.85
    @State private var headerOpacity: Double      = 0

    enum FilterOption: String, CaseIterable {
        case all = "All", unlocked = "Unlocked", locked = "Locked"
    }

    private var filtered: [Achievement] {
        let base: [Achievement]
        switch filter {
        case .all:      base = engine.achievements
        case .unlocked: base = engine.achievements.filter {  $0.isUnlocked }
        case .locked:   base = engine.achievements.filter { !$0.isUnlocked }
        }
        return base.sorted {
            if $0.isUnlocked != $1.isUnlocked { return $0.isUnlocked }
            return $0.progress > $1.progress
        }
    }

    private var unlockedCount: Int { engine.achievements.filter { $0.isUnlocked }.count }
    private var totalCount:    Int { engine.achievements.count }
    private var overallPct:  Double { totalCount > 0 ? Double(unlockedCount)/Double(totalCount) : 0 }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex:"F0F8FF"), Color(hex:"E0EFFF")]),
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroHeader
                        .scaleEffect(headerScale).opacity(headerOpacity)
                    tierRow
                    filterPicker
                    grid
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            engine.evaluate(trips: storage.trips)
            withAnimation(.spring(response:0.7, dampingFraction:0.65)) {
                headerScale = 1; headerOpacity = 1
            }
        }
        .sheet(item: $selected) { AchievementDetailSheet(achievement: $0) }
    }

    // MARK: Hero Header
    private var heroHeader: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(RadialGradient(gradient: Gradient(colors: [Color(hex:"FFD700").opacity(0.35), .clear]),
                                        center: .center, startRadius: 10, endRadius: 70))
                    .frame(width: 130, height: 130)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(LinearGradient(colors: [Color(hex:"FFD700"), Color(hex:"FFA000")],
                                                   startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex:"FFD700").opacity(0.5), radius: 12)
            }

            VStack(spacing: 6) {
                Text("\(unlockedCount) / \(totalCount)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex:"1E3A5F"))
                Text("achievements unlocked")
                    .font(.system(size: 15)).foregroundColor(Color(hex:"1E3A5F").opacity(0.6))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10).fill(Color(hex:"4A90E2").opacity(0.15)).frame(height:12)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors:[Color(hex:"4A90E2"),Color(hex:"7CB9E8")],
                                             startPoint:.leading, endPoint:.trailing))
                        .frame(width: geo.size.width * CGFloat(overallPct), height: 12)
                        .animation(.spring(response:1.0, dampingFraction:0.7), value: overallPct)
                }
            }
            .frame(height: 12).padding(.horizontal, 20)

            Text("\(Int(overallPct * 100))% complete")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex:"4A90E2"))
        }
        .padding(.vertical, 28).padding(.horizontal, 20)
        .background(RoundedRectangle(cornerRadius:28).fill(Color.white)
            .shadow(color:.black.opacity(0.09), radius:20, y:8))
        .padding(.horizontal, 16)
    }

    // MARK: Tier Row
    private var tierRow: some View {
        HStack(spacing: 12) {
            ForEach([Achievement.Tier.gold, .silver, .bronze], id:\.self) { tier in
                let earned = engine.achievements.filter { $0.tier==tier && $0.isUnlocked }.count
                let total  = engine.achievements.filter { $0.tier==tier }.count
                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color(hex:tier.colorHex).opacity(0.15)).frame(width:48,height:48)
                        Image(systemName:"medal.fill").font(.system(size:22)).foregroundColor(Color(hex:tier.colorHex))
                    }
                    Text("\(earned)/\(total)").font(.system(size:15,weight:.bold)).foregroundColor(Color(hex:"1E3A5F"))
                    Text(tier.label).font(.system(size:11)).foregroundColor(Color(hex:"1E3A5F").opacity(0.6))
                }
                .frame(maxWidth:.infinity).padding(.vertical,16)
                .background(Color.white).cornerRadius(18)
                .shadow(color:Color(hex:tier.colorHex).opacity(0.2), radius:8, y:4)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Filter Picker
    private var filterPicker: some View {
        HStack(spacing: 0) {
            ForEach(FilterOption.allCases, id:\.self) { option in
                Button(action: {
                    withAnimation(.spring(response:0.35, dampingFraction:0.7)) { filter = option }
                }) {
                    Text(option.rawValue)
                        .font(.system(size:14, weight: filter==option ? .bold : .regular))
                        .foregroundColor(filter==option ? .white : Color(hex:"1E3A5F").opacity(0.6))
                        .frame(maxWidth:.infinity).padding(.vertical,10)
                        .background(filter==option ? Color(hex:"4A90E2") : Color.clear)
                        .cornerRadius(12)
                }
            }
        }
        .padding(4).background(Color(hex:"4A90E2").opacity(0.1)).cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: Grid
    private var grid: some View {
        LazyVGrid(columns:[GridItem(.flexible(),spacing:12), GridItem(.flexible(),spacing:12)], spacing:14) {
            ForEach(filtered) { achievement in
                AchievementCard(achievement: achievement)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style:.medium).impactOccurred()
                        selected = achievement
                    }
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(response:0.4, dampingFraction:0.75), value: filter)
    }
}

// MARK: ── Achievement Card ────────────────────────────────────

struct AchievementCard: View {
    let achievement: Achievement
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked
                          ? Color(hex:achievement.colorHex).opacity(0.18)
                          : Color(hex:"CCCCCC").opacity(0.18))
                    .frame(width:64, height:64)

                if achievement.isUnlocked {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors:[Color(hex:achievement.tier.colorHex).opacity(0.8),
                                        Color(hex:achievement.tier.colorHex).opacity(0.2)],
                                startPoint:.topLeading, endPoint:.bottomTrailing),
                            lineWidth:2.5)
                        .frame(width:64, height:64)
                }

                Image(systemName: achievement.icon)
                    .font(.system(size:28))
                    .foregroundStyle(
                        achievement.isUnlocked
                        ? LinearGradient(colors:[Color(hex:achievement.colorHex),
                                                 Color(hex:achievement.colorHex).opacity(0.7)],
                                         startPoint:.top, endPoint:.bottom)
                        : LinearGradient(colors:[Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                         startPoint:.top, endPoint:.bottom)
                    )
                    .saturation(achievement.isUnlocked ? 1 : 0)
            }
            .shadow(color: achievement.isUnlocked
                    ? Color(hex:achievement.colorHex).opacity(0.4) : .clear, radius:8)

            Text(achievement.title)
                .font(.system(size:13, weight:.bold))
                .foregroundColor(achievement.isUnlocked
                                 ? Color(hex:"1E3A5F") : Color(hex:"1E3A5F").opacity(0.4))
                .multilineTextAlignment(.center).lineLimit(2)

            Text(achievement.tier.label)
                .font(.system(size:10, weight:.semibold))
                .foregroundColor(achievement.isUnlocked
                                 ? Color(hex:achievement.tier.colorHex) : Color.gray.opacity(0.5))
                .padding(.horizontal,8).padding(.vertical,3)
                .background(Capsule().fill(
                    achievement.isUnlocked
                    ? Color(hex:achievement.tier.colorHex).opacity(0.15)
                    : Color.gray.opacity(0.08)))

            // Progress bar
            VStack(spacing:4) {
                GeometryReader { geo in
                    ZStack(alignment:.leading) {
                        RoundedRectangle(cornerRadius:4).fill(Color.gray.opacity(0.15)).frame(height:5)
                        RoundedRectangle(cornerRadius:4)
                            .fill(achievement.isUnlocked ? Color(hex:achievement.colorHex) : Color(hex:"4A90E2").opacity(0.6))
                            .frame(width: appeared ? geo.size.width * CGFloat(achievement.progress) : 0, height:5)
                            .animation(.spring(response:1.0, dampingFraction:0.7).delay(0.15), value:appeared)
                    }
                }
                .frame(height:5)
                Text(achievement.progressLabel)
                    .font(.system(size:10)).foregroundColor(Color(hex:"1E3A5F").opacity(0.5))
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius:20).fill(Color.white)
                if achievement.isUnlocked {
                    RoundedRectangle(cornerRadius:20)
                        .fill(LinearGradient(
                            colors:[.clear, Color(hex:achievement.tier.colorHex).opacity(0.07), .clear],
                            startPoint:.topLeading, endPoint:.bottomTrailing))
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius:20))
        .shadow(color: achievement.isUnlocked
                ? Color(hex:achievement.colorHex).opacity(0.15) : Color.black.opacity(0.05),
                radius: achievement.isUnlocked ? 12 : 6, y:4)
        .overlay(
            !achievement.isUnlocked
            ? VStack { HStack { Spacer()
                Image(systemName:"lock.fill").font(.system(size:11))
                    .foregroundColor(.gray.opacity(0.4)).padding(8)
            }; Spacer() } : nil
        )
        .onAppear { withAnimation { appeared = true } }
    }
}

// MARK: ── Achievement Detail Sheet ───────────────────────────

struct AchievementDetailSheet: View {
    let achievement: Achievement
    @Environment(\.presentationMode) var presentationMode
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [
                    achievement.isUnlocked ? Color(hex:achievement.colorHex).opacity(0.08) : Color(hex:"F5F5F5"),
                    Color.white
                ]), startPoint:.top, endPoint:.bottom).ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()
                    // Big icon with glow
                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                gradient: Gradient(colors:[
                                    Color(hex: achievement.isUnlocked ? achievement.colorHex : "CCCCCC").opacity(0.3),
                                    .clear]),
                                center:.center, startRadius:20, endRadius:90))
                            .frame(width:180, height:180)
                        Image(systemName: achievement.icon)
                            .font(.system(size:80))
                            .foregroundStyle(
                                achievement.isUnlocked
                                ? LinearGradient(colors:[Color(hex:achievement.colorHex),
                                                         Color(hex:achievement.colorHex).opacity(0.6)],
                                                 startPoint:.top, endPoint:.bottom)
                                : LinearGradient(colors:[Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                                                 startPoint:.top, endPoint:.bottom))
                            .saturation(achievement.isUnlocked ? 1 : 0)
                            .scaleEffect(iconScale).opacity(iconOpacity)
                    }
                    .shadow(color: achievement.isUnlocked
                            ? Color(hex:achievement.colorHex).opacity(0.4) : .clear, radius:20)

                    // Status badge
                    HStack(spacing:6) {
                        Image(systemName: achievement.isUnlocked ? "checkmark.circle.fill" : "lock.circle.fill")
                        Text(achievement.isUnlocked ? "Unlocked" : "Locked")
                    }
                    .font(.system(size:14, weight:.semibold))
                    .foregroundColor(achievement.isUnlocked ? Color(hex:"4CAF50") : .gray)
                    .padding(.horizontal,16).padding(.vertical,8)
                    .background(Capsule().fill(
                        achievement.isUnlocked ? Color(hex:"4CAF50").opacity(0.12) : Color.gray.opacity(0.1)))

                    VStack(spacing:10) {
                        Text(achievement.title).font(.system(size:26,weight:.black)).foregroundColor(Color(hex:"1E3A5F"))
                        Text(achievement.description).font(.system(size:16))
                            .foregroundColor(Color(hex:"1E3A5F").opacity(0.7))
                            .multilineTextAlignment(.center).padding(.horizontal,30)
                    }

                    HStack(spacing:6) {
                        Image(systemName:"medal.fill").foregroundColor(Color(hex:achievement.tier.colorHex))
                        Text(achievement.tier.label).font(.system(size:14,weight:.semibold))
                            .foregroundColor(Color(hex:achievement.tier.colorHex))
                    }
                    .padding(.horizontal,18).padding(.vertical,10)
                    .background(RoundedRectangle(cornerRadius:14).fill(Color(hex:achievement.tier.colorHex).opacity(0.12)))

                    // Progress bar
                    VStack(spacing:12) {
                        HStack {
                            Text("Progress").font(.system(size:16,weight:.semibold)).foregroundColor(Color(hex:"1E3A5F"))
                            Spacer()
                            Text(achievement.progressLabel).font(.system(size:15,weight:.bold))
                                .foregroundColor(Color(hex: achievement.isUnlocked ? achievement.colorHex : "4A90E2"))
                        }
                        GeometryReader { geo in
                            ZStack(alignment:.leading) {
                                RoundedRectangle(cornerRadius:8).fill(Color.gray.opacity(0.12)).frame(height:14)
                                RoundedRectangle(cornerRadius:8)
                                    .fill(LinearGradient(
                                        colors:[Color(hex: achievement.isUnlocked ? achievement.colorHex : "4A90E2"),
                                                Color(hex: achievement.isUnlocked ? achievement.colorHex : "7CB9E8").opacity(0.7)],
                                        startPoint:.leading, endPoint:.trailing))
                                    .frame(width: geo.size.width * CGFloat(achievement.progress), height:14)
                                    .animation(.spring(response:1.2, dampingFraction:0.7), value:achievement.progress)
                            }
                        }.frame(height:14)
                    }
                    .padding(18).background(Color.white).cornerRadius(18)
                    .shadow(color:.black.opacity(0.06), radius:10, y:4).padding(.horizontal,20)

                    if achievement.isUnlocked, let date = achievement.unlockedDate {
                        HStack(spacing:6) {
                            Image(systemName:"calendar.badge.checkmark").foregroundColor(Color(hex:"4CAF50"))
                            Text("Unlocked on \(date.formatted(date:.long, time:.omitted))")
                                .font(.system(size:13)).foregroundColor(Color(hex:"1E3A5F").opacity(0.6))
                        }
                    }
                    Spacer()
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button(action:{ presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName:"xmark.circle.fill").font(.title3)
                            .foregroundColor(Color(hex:"1E3A5F").opacity(0.4))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response:0.6, dampingFraction:0.55)) { iconScale=1; iconOpacity=1 }
        }
    }
}

// MARK: ── Achievements Summary Widget ─────────────────────────
/// Embed in AnalyticsView / StatisticsView — links to AchievementsView.

struct AchievementsSummaryCard: View {
    @StateObject private var engine = AchievementEngine.shared

    private var unlocked: Int { engine.achievements.filter { $0.isUnlocked }.count }
    private var total:    Int { engine.achievements.count }
    private var latest: [Achievement] {
        engine.achievements.filter { $0.isUnlocked }
            .sorted { ($0.unlockedDate ?? .distantPast) > ($1.unlockedDate ?? .distantPast) }
            .prefix(3).map { $0 }
    }

    var body: some View {
        NavigationLink(destination: AchievementsView()) {
            VStack(alignment:.leading, spacing:16) {
                HStack {
                    Label("Achievements", systemImage:"trophy.fill")
                        .font(.system(size:18,weight:.bold)).foregroundColor(Color(hex:"1E3A5F"))
                    Spacer()
                    Image(systemName:"chevron.right")
                        .font(.system(size:13,weight:.semibold)).foregroundColor(Color(hex:"1E3A5F").opacity(0.3))
                }
                HStack(spacing:20) {
                    ZStack {
                        Circle().stroke(Color(hex:"FFD700").opacity(0.2), lineWidth:8).frame(width:72,height:72)
                        Circle()
                            .trim(from:0, to: total>0 ? CGFloat(unlocked)/CGFloat(total) : 0)
                            .stroke(LinearGradient(colors:[Color(hex:"FFD700"),Color(hex:"FFA000")],
                                                   startPoint:.topLeading, endPoint:.bottomTrailing),
                                    style:StrokeStyle(lineWidth:8, lineCap:.round))
                            .frame(width:72,height:72).rotationEffect(.degrees(-90))
                            .animation(.spring(), value:unlocked)
                        VStack(spacing:1) {
                            Text("\(unlocked)").font(.system(size:20,weight:.black,design:.rounded)).foregroundColor(Color(hex:"1E3A5F"))
                            Text("/ \(total)").font(.system(size:11)).foregroundColor(Color(hex:"1E3A5F").opacity(0.5))
                        }
                    }
                    VStack(alignment:.leading, spacing:8) {
                        Text("Recently unlocked:").font(.system(size:12)).foregroundColor(Color(hex:"1E3A5F").opacity(0.6))
                        if latest.isEmpty {
                            Text("Nothing unlocked yet")
                                .font(.system(size:13,weight:.medium)).foregroundColor(Color(hex:"1E3A5F").opacity(0.45))
                        } else {
                            ForEach(latest) { a in
                                HStack(spacing:6) {
                                    Image(systemName:a.icon).font(.system(size:13)).foregroundColor(Color(hex:a.colorHex))
                                    Text(a.title).font(.system(size:13,weight:.semibold)).foregroundColor(Color(hex:"1E3A5F"))
                                }
                            }
                        }
                    }
                }
            }
            .padding(20).background(Color.white).cornerRadius(22)
            .shadow(color:Color(hex:"FFD700").opacity(0.12), radius:14, y:6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: ── Unlock Toast ───────────────────────────────────────
/// Place at the top of ContentView's ZStack to show on unlock.

struct AchievementUnlockToast: View {
    let achievement: Achievement
    @State private var offset:  CGFloat = -120
    @State private var opacity: Double  = 0

    var body: some View {
        HStack(spacing:14) {
            ZStack {
                Circle().fill(Color(hex:achievement.colorHex).opacity(0.2)).frame(width:46,height:46)
                Image(systemName:achievement.icon).font(.system(size:22)).foregroundColor(Color(hex:achievement.colorHex))
            }
            VStack(alignment:.leading, spacing:2) {
                Text("🏆 Achievement Unlocked!")
                    .font(.system(size:12,weight:.semibold)).foregroundColor(Color(hex:"1E3A5F").opacity(0.6))
                Text(achievement.title).font(.system(size:15,weight:.bold)).foregroundColor(Color(hex:"1E3A5F"))
            }
            Spacer()
            Image(systemName:"medal.fill").foregroundColor(Color(hex:achievement.tier.colorHex))
        }
        .padding(.horizontal,16).padding(.vertical,12)
        .background(RoundedRectangle(cornerRadius:18).fill(Color.white)
            .shadow(color:Color(hex:achievement.colorHex).opacity(0.25), radius:16, y:6))
        .padding(.horizontal,16)
        .offset(y:offset).opacity(opacity)
        .onAppear {
            withAnimation(.spring(response:0.5, dampingFraction:0.65)) { offset=0; opacity=1 }
            DispatchQueue.main.asyncAfter(deadline:.now()+3.2) {
                withAnimation(.easeOut(duration:0.4)) { offset = -120; opacity=0 }
            }
        }
    }
}
