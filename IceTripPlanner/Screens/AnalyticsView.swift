import SwiftUI

#Preview {
    AnalyticsView()
}

struct AnalyticsView: View {
    @StateObject private var storage = StorageManager.shared
    @State private var period: Period = .allTime
    @State private var appeared = false

    enum Period: String, CaseIterable {
        case thisYear  = "This Year"
        case lastYear  = "Last Year"
        case allTime   = "All Time"
    }

    // MARK: - Filtered data helpers
    private var filtered: [Trip] {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case .thisYear:
            return storage.trips.filter { cal.isDate($0.date, equalTo: now, toGranularity: .year) }
        case .lastYear:
            guard let ly = cal.date(byAdding: .year, value: -1, to: now) else { return storage.trips }
            return storage.trips.filter { cal.isDate($0.date, equalTo: ly, toGranularity: .year) }
        case .allTime:
            return storage.trips
        }
    }

    private var completed: [Trip]    { filtered.filter { $0.status == .completed } }
    private var cancelled: [Trip]    { filtered.filter { $0.status == .cancelled } }
    private var planned:   [Trip]    { filtered.filter { $0.status == .planned   } }
    private var completionRate: Double { filtered.isEmpty ? 0 : Double(completed.count)/Double(filtered.count) }
    private var avgBite: Double {
        let s = completed.compactMap { $0.result?.biteScore }
        return s.isEmpty ? 0 : Double(s.reduce(0,+))/Double(s.count)
    }
    private var totalCatch: Int { completed.compactMap { $0.result?.catchCount }.reduce(0,+) }
    private var avgCatch: Double { completed.isEmpty ? 0 : Double(totalCatch)/Double(completed.count) }
    private var iceCount:    Int { filtered.filter { $0.season == .ice    }.count }
    private var summerCount: Int { filtered.filter { $0.season == .summer }.count }

    private var monthlyData: [MonthBar] {
        (1...12).map { m in
            MonthBar(month: m, count: filtered.filter {
                Calendar.current.component(.month, from: $0.date) == m
            }.count)
        }
    }
    private var biteData: [BiteBar] {
        let scores = completed.compactMap { $0.result?.biteScore }
        return (1...5).map {
            BiteBar(
                score: $0,
                count: 0 // scores.filter { $0 == $1 }.count
            )
        }
    }
    
    private var bestMonth: String {
        guard let best = monthlyData.max(by: { $0.count < $1.count }), best.count > 0 else { return "—" }
        return Calendar.current.monthSymbols[best.month - 1]
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color(hex:"F0F8FF"), Color(hex:"E0EFFF")]),
                               startPoint:.top, endPoint:.bottom).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        periodPicker

                        kpiRow
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)

                        statusDonutCard
                        monthlyBarCard
                        biteScoreCard
                        seasonCard
                        AchievementsSummaryCard().padding(.horizontal, 16)
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                AchievementEngine.shared.evaluate(trips: storage.trips)
                withAnimation(.spring(response:0.7, dampingFraction:0.7).delay(0.1)) { appeared = true }
            }
        }
    }

    // MARK: - Period Picker
    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Period.allCases, id:\.self) { p in
                    Button(action: {
                        withAnimation(.spring(response:0.35, dampingFraction:0.7)) { period = p }
                    }) {
                        Text(p.rawValue)
                            .font(.system(size:14, weight: period==p ? .bold : .medium))
                            .foregroundColor(period==p ? .white : Color(hex:"1E3A5F").opacity(0.6))
                            .padding(.horizontal,18).padding(.vertical,9)
                            .background(Capsule().fill(period==p ? Color(hex:"4A90E2") : Color.white))
                            .shadow(color: period==p ? Color(hex:"4A90E2").opacity(0.35) : .clear, radius:8, y:3)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - KPI Row
    private var kpiRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                KPICard(icon:"calendar",              label:"Trips",        value:"\(filtered.count)",             color:"4A90E2")
                KPICard(icon:"checkmark.seal.fill",   label:"Completed",    value:"\(completed.count)",            color:"4CAF50")
                KPICard(icon:"bolt.fill",             label:"Avg Bite",     value:String(format:"%.1f",avgBite),   color:"FFB74D")
                KPICard(icon:"fish.fill",             label:"Total Catch",  value:"\(totalCatch)",                 color:"7CB9E8")
                KPICard(icon:"chart.pie.fill",        label:"Success Rate", value:"\(Int(completionRate*100))%",   color:"9C27B0")
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Status Donut
    private var statusDonutCard: some View {
        AnalyticsCard(title:"Trip Status Breakdown", icon:"chart.pie.fill") {
            HStack(spacing: 24) {
                ZStack {
                    DonutChart(segments:[
                        DonutSegment(value:Double(completed.count), color:Color(hex:"4CAF50")),
                        DonutSegment(value:Double(planned.count),   color:Color(hex:"4A90E2")),
                        DonutSegment(value:Double(cancelled.count), color:Color(hex:"E53935")),
                    ])
                    .frame(width:130, height:130)

                    VStack(spacing:2) {
                        Text("\(filtered.count)")
                            .font(.system(size:28,weight:.black,design:.rounded)).foregroundColor(Color(hex:"1E3A5F"))
                        Text("total").font(.system(size:12)).foregroundColor(Color(hex:"1E3A5F").opacity(0.5))
                    }
                }

                VStack(alignment:.leading, spacing:12) {
                    DonutLegendRow(color:"4CAF50", label:"Completed", count:completed.count,  total:filtered.count)
                    DonutLegendRow(color:"4A90E2", label:"Planned",   count:planned.count,    total:filtered.count)
                    DonutLegendRow(color:"E53935", label:"Cancelled", count:cancelled.count,  total:filtered.count)
                }
                Spacer()
            }
        }
    }

    // MARK: - Monthly Bars
    private var monthlyBarCard: some View {
        AnalyticsCard(title:"Monthly Activity", icon:"calendar.badge.clock") {
            VStack(spacing: 16) {
                MonthlyBarChart(data: monthlyData).frame(height:140)

                if !filtered.isEmpty {
                    HStack(spacing:8) {
                        Image(systemName:"star.fill").foregroundColor(Color(hex:"FFD700"))
                        Text("Best month: \(bestMonth)")
                            .font(.system(size:14,weight:.semibold)).foregroundColor(Color(hex:"1E3A5F"))
                    }
                    .padding(.horizontal,16).padding(.vertical,8)
                    .background(Color(hex:"FFD700").opacity(0.1)).cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Bite Score
    private var biteScoreCard: some View {
        AnalyticsCard(title:"Bite Score Distribution", icon:"bolt.circle.fill") {
            VStack(spacing: 16) {
                BiteScoreChart(data: biteData).frame(height:120)

                HStack(spacing:20) {
                    AnalyticsMetric(label:"Avg Bite Score",     value:String(format:"%.1f / 5.0",avgBite), icon:"star.fill",  color:"FFB74D")
                    Divider()
                    AnalyticsMetric(label:"Avg Catch / Trip",   value:String(format:"%.1f fish",avgCatch), icon:"fish.fill",  color:"7CB9E8")
                }
                .frame(height:60)
            }
        }
    }

    // MARK: - Season Split
    private var seasonCard: some View {
        AnalyticsCard(title:"Season Split", icon:"thermometer.sun.fill") {
            HStack(spacing:20) {
                SeasonDonutCard(icon:"snowflake",    label:"Ice",    count:iceCount,    total:filtered.count, color:"7CB9E8")
                Divider()
                SeasonDonutCard(icon:"sun.max.fill", label:"Summer", count:summerCount, total:filtered.count, color:"FFB74D")
            }
            .frame(height:100)
        }
    }
}

// MARK: ── Reusable Analytics Card Container ─────────────────

struct AnalyticsCard<Content: View>: View {
    let title: String
    let icon:  String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment:.leading, spacing:18) {
            Label(title, systemImage:icon)
                .font(.system(size:17,weight:.bold)).foregroundColor(Color(hex:"1E3A5F"))
            content
        }
        .padding(20).background(Color.white).cornerRadius(22)
        .shadow(color:.black.opacity(0.07), radius:14, y:6)
        .padding(.horizontal, 16)
    }
}

// MARK: ── KPI Card ────────────────────────────────────────────

struct KPICard: View {
    let icon:  String
    let label: String
    let value: String
    let color: String
    @State private var appeared = false

    var body: some View {
        VStack(spacing:10) {
            ZStack {
                RoundedRectangle(cornerRadius:14).fill(Color(hex:color).opacity(0.15)).frame(width:52,height:52)
                Image(systemName:icon).font(.system(size:22)).foregroundColor(Color(hex:color))
            }
            Text(value)
                .font(.system(size:22,weight:.black,design:.rounded)).foregroundColor(Color(hex:"1E3A5F"))
            Text(label).font(.system(size:11)).foregroundColor(Color(hex:"1E3A5F").opacity(0.55))
        }
        .frame(width:95).padding(.vertical,16)
        .background(Color.white).cornerRadius(18)
        .shadow(color:Color(hex:color).opacity(0.12), radius:10, y:5)
        .onAppear { withAnimation(.spring(response:0.6).delay(0.2)) { appeared = true } }
    }
}

// MARK: ── Donut Chart ─────────────────────────────────────────

struct DonutSegment { let value: Double; let color: Color }

struct DonutChart: View {
    let segments: [DonutSegment]
    @State private var appeared = false

    private var total: Double { segments.map { $0.value }.reduce(0,+) }

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.1), lineWidth:22)
            if total > 0 {
                let angles = buildAngles()
                ForEach(Array(segments.enumerated()), id:\.offset) { idx, seg in
                    if seg.value > 0 {
                        Circle()
                            .trim(from: appeared ? CGFloat(angles[idx].0) : 0,
                                  to:   appeared ? CGFloat(angles[idx].1) : 0)
                            .stroke(seg.color, style:StrokeStyle(lineWidth:22, lineCap:.round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response:1.0, dampingFraction:0.7).delay(Double(idx)*0.15),
                                       value:appeared)
                    }
                }
            }
        }
        .onAppear { appeared = true }
    }

    private func buildAngles() -> [(Double, Double)] {
        var result: [(Double,Double)] = []
        var cum = 0.0
        for s in segments {
            let frac = total > 0 ? s.value/total : 0
            result.append((cum, cum+frac)); cum += frac
        }
        return result
    }
}

struct DonutLegendRow: View {
    let color: String; let label: String; let count: Int; let total: Int
    private var pct: Int { total > 0 ? Int(Double(count)/Double(total)*100) : 0 }
    var body: some View {
        HStack(spacing:8) {
            Circle().fill(Color(hex:color)).frame(width:10,height:10)
            Text(label).font(.system(size:13)).foregroundColor(Color(hex:"1E3A5F").opacity(0.7))
            Spacer()
            Text("\(count) (\(pct)%)").font(.system(size:13,weight:.semibold)).foregroundColor(Color(hex:"1E3A5F"))
        }
    }
}

// MARK: ── Monthly Bar Chart ───────────────────────────────────

struct MonthBar: Identifiable {
    let id = UUID()
    let month: Int
    let count: Int
    var short: String { Calendar.current.shortMonthSymbols[month-1] }
}

struct MonthlyBarChart: View {
    let data: [MonthBar]
    @State private var appeared = false
    private var maxCount: Int { max(data.map { $0.count }.max() ?? 1, 1) }

    var body: some View {
        GeometryReader { geo in
            let barW = (geo.size.width - CGFloat(data.count-1)*4) / CGFloat(data.count)
            HStack(alignment:.bottom, spacing:4) {
                ForEach(data) { bar in
                    VStack(spacing:4) {
                        if bar.count > 0 {
                            Text("\(bar.count)").font(.system(size:9,weight:.bold))
                                .foregroundColor(Color(hex:"4A90E2")).opacity(appeared ? 1 : 0)
                        }
                        RoundedRectangle(cornerRadius:5)
                            .fill(bar.count == maxCount && maxCount > 0
                                  ? LinearGradient(colors:[Color(hex:"FFD700"),Color(hex:"FF9800")],
                                                   startPoint:.top, endPoint:.bottom)
                                  : LinearGradient(colors:[Color(hex:"4A90E2"),Color(hex:"7CB9E8")],
                                                   startPoint:.top, endPoint:.bottom))
                            .frame(width:barW,
                                   height: appeared
                                   ? max(4, geo.size.height*0.75*CGFloat(bar.count)/CGFloat(maxCount)) : 4)
                            .animation(
                                .spring(response:0.7, dampingFraction:0.65)
                                    .delay(Double(data.firstIndex(where:{$0.id==bar.id}) ?? 0)*0.04),
                                value:appeared)
                        Text(bar.short).font(.system(size:8,weight:.medium))
                            .foregroundColor(Color(hex:"1E3A5F").opacity(0.5))
                    }
                }
            }
            .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.bottom)
        }
        .onAppear { withAnimation { appeared = true } }
    }
}

// MARK: ── Bite Score Chart ────────────────────────────────────

struct BiteBar: Identifiable {
    let id = UUID();
    let score: Int;
    let count: Int
}

struct BiteScoreChart: View {
    let data: [BiteBar]
    @State private var appeared = false
    private var maxCount: Int { max(data.map { $0.count }.max() ?? 1, 1) }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment:.bottom, spacing:12) {
                ForEach(data) { bar in
                    VStack(spacing:6) {
                        if bar.count > 0 {
                            Text("\(bar.count)").font(.system(size:12,weight:.bold))
                                .foregroundColor(Color(hex:"FFB74D")).opacity(appeared ? 1 : 0)
                        }
                        RoundedRectangle(cornerRadius:8)
                            .fill(LinearGradient(colors:barColors(bar.score),
                                                 startPoint:.top, endPoint:.bottom))
                            .frame(height: appeared
                                   ? max(8, geo.size.height*0.8*CGFloat(bar.count)/CGFloat(maxCount)) : 8)
                            .animation(.spring(response:0.8,dampingFraction:0.65).delay(Double(bar.score)*0.1),
                                       value:appeared)
                        HStack(spacing:1) {
                            ForEach(1...bar.score, id:\.self) { _ in
                                Image(systemName:"star.fill").font(.system(size:6))
                                    .foregroundColor(Color(hex:"FFB74D"))
                            }
                        }
                    }
                    .frame(maxWidth:.infinity)
                }
            }
            .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.bottom)
        }
        .onAppear { withAnimation { appeared = true } }
    }

    private func barColors(_ score: Int) -> [Color] {
        switch score {
        case 1:  return [Color(hex:"E53935"), Color(hex:"EF9A9A")]
        case 2:  return [Color(hex:"FF9800"), Color(hex:"FFCC80")]
        case 3:  return [Color(hex:"FFD700"), Color(hex:"FFF176")]
        case 4:  return [Color(hex:"66BB6A"), Color(hex:"A5D6A7")]
        default: return [Color(hex:"4CAF50"), Color(hex:"4A90E2")]
        }
    }
}

// MARK: ── Season Donut Card ───────────────────────────────────

struct SeasonDonutCard: View {
    let icon: String; let label: String
    let count: Int; let total: Int; let color: String
    private var pct: Int { total > 0 ? Int(Double(count)/Double(total)*100) : 0 }
    @State private var appeared = false

    var body: some View {
        VStack(spacing:8) {
            ZStack {
                Circle().stroke(Color(hex:color).opacity(0.2), lineWidth:8).frame(width:70,height:70)
                Circle()
                    .trim(from:0, to: appeared ? CGFloat(pct)/100 : 0)
                    .stroke(Color(hex:color), style:StrokeStyle(lineWidth:8, lineCap:.round))
                    .frame(width:70,height:70).rotationEffect(.degrees(-90))
                    .animation(.spring(response:1.0,dampingFraction:0.7), value:appeared)
                Image(systemName:icon).font(.system(size:22)).foregroundColor(Color(hex:color))
            }
            Text("\(count) (\(pct)%)").font(.system(size:15,weight:.bold)).foregroundColor(Color(hex:"1E3A5F"))
            Text(label).font(.system(size:12)).foregroundColor(Color(hex:"1E3A5F").opacity(0.6))
        }
        .frame(maxWidth:.infinity)
        .onAppear { withAnimation { appeared = true } }
    }
}

// MARK: ── Analytics Metric ───────────────────────────────────

struct AnalyticsMetric: View {
    let label: String; let value: String; let icon: String; let color: String
    var body: some View {
        VStack(spacing:6) {
            Image(systemName:icon).font(.system(size:20)).foregroundColor(Color(hex:color))
            Text(value).font(.system(size:16,weight:.bold)).foregroundColor(Color(hex:"1E3A5F"))
            Text(label).font(.system(size:11)).foregroundColor(Color(hex:"1E3A5F").opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth:.infinity)
    }
}
