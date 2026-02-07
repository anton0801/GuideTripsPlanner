import Foundation

// MARK: - Trip Model
struct Trip: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var date: Date
    var season: Season
    var placeName: String
    var status: TripStatus
    var notes: String
    var checklistItems: [ChecklistItem]
    var tasks: [TripTask]
    var result: TripResult?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        season: Season = .ice,
        placeName: String,
        status: TripStatus = .planned,
        notes: String = "",
        checklistItems: [ChecklistItem] = [],
        tasks: [TripTask] = [],
        result: TripResult? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.season = season
        self.placeName = placeName
        self.status = status
        self.notes = notes
        self.checklistItems = checklistItems
        self.tasks = tasks
        self.result = result
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var checklistProgress: Double {
        guard !checklistItems.isEmpty else { return 0 }
        let completed = checklistItems.filter { $0.isCompleted }.count
        return Double(completed) / Double(checklistItems.count)
    }
    
    var taskProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(tasks.count)
    }
}

// MARK: - Season Enum
enum Season: String, Codable, CaseIterable {
    case ice = "Ice"
    case summer = "Summer"
    
    var icon: String {
        switch self {
        case .ice: return "snowflake"
        case .summer: return "sun.max.fill"
        }
    }
    
    var color: String {
        switch self {
        case .ice: return "7CB9E8"
        case .summer: return "FFB74D"
        }
    }
}

// MARK: - Trip Status Enum
enum TripStatus: String, Codable, CaseIterable {
    case planned = "Planned"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    var color: String {
        switch self {
        case .planned: return "4A90E2"
        case .completed: return "4CAF50"
        case .cancelled: return "E53935"
        }
    }
    
    var icon: String {
        switch self {
        case .planned: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// MARK: - Checklist Item
struct ChecklistItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var category: ChecklistCategory
    var isCompleted: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        category: ChecklistCategory,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isCompleted = isCompleted
    }
}

// MARK: - Checklist Category
enum ChecklistCategory: String, Codable, CaseIterable {
    case gear = "Gear"
    case clothes = "Clothes"
    case safety = "Safety"
    
    var icon: String {
        switch self {
        case .gear: return "bag.fill"
        case .clothes: return "tshirt.fill"
        case .safety: return "cross.case.fill"
        }
    }
    
    var color: String {
        switch self {
        case .gear: return "4A90E2"
        case .clothes: return "9C27B0"
        case .safety: return "E53935"
        }
    }
}

// MARK: - Trip Task
struct TripTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var deadline: Date?
    var priority: TaskPriority
    var isCompleted: Bool
    var completedAt: Date?
    
    init(
        id: UUID = UUID(),
        title: String,
        deadline: Date? = nil,
        priority: TaskPriority = .medium,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.deadline = deadline
        self.priority = priority
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

// MARK: - Task Priority
enum TaskPriority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: String {
        switch self {
        case .low: return "4CAF50"
        case .medium: return "FF9800"
        case .high: return "E53935"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "arrow.down.circle.fill"
        case .medium: return "minus.circle.fill"
        case .high: return "arrow.up.circle.fill"
        }
    }
}

// MARK: - Trip Result
struct TripResult: Codable, Equatable {
    var biteScore: Int // 1-5
    var catchCount: Int
    var bestMoment: String
    var lessonsLearned: String
    var completedDate: Date
    
    init(
        biteScore: Int = 3,
        catchCount: Int = 0,
        bestMoment: String = "",
        lessonsLearned: String = "",
        completedDate: Date = Date()
    ) {
        self.biteScore = biteScore
        self.catchCount = catchCount
        self.bestMoment = bestMoment
        self.lessonsLearned = lessonsLearned
        self.completedDate = completedDate
    }
}

// MARK: - App Settings
struct AppSettings: Codable {
    var defaultSeason: Season
    var weekStartDay: Int // 0 = Sunday, 1 = Monday
    var checklistPresets: [String: [ChecklistItem]]
    
    init(
        defaultSeason: Season = .ice,
        weekStartDay: Int = 1,
        checklistPresets: [String: [ChecklistItem]] = [:]
    ) {
        self.defaultSeason = defaultSeason
        self.weekStartDay = weekStartDay
        self.checklistPresets = checklistPresets
    }
    
    static var `default`: AppSettings {
        AppSettings(
            defaultSeason: .ice,
            weekStartDay: 1,
            checklistPresets: [
                "Ice Fishing": ChecklistPreset.iceFishingItems,
                "Summer Fishing": ChecklistPreset.summerFishingItems
            ]
        )
    }
}

// MARK: - Checklist Presets
struct ChecklistPreset {
    static let iceFishingItems: [ChecklistItem] = [
        // Gear
        ChecklistItem(name: "Ice auger", category: .gear),
        ChecklistItem(name: "Fishing rod", category: .gear),
        ChecklistItem(name: "Tackle box", category: .gear),
        ChecklistItem(name: "Bait", category: .gear),
        ChecklistItem(name: "Ice shelter", category: .gear),
        ChecklistItem(name: "Bucket/seat", category: .gear),
        // Clothes
        ChecklistItem(name: "Insulated boots", category: .clothes),
        ChecklistItem(name: "Winter jacket", category: .clothes),
        ChecklistItem(name: "Thermal layers", category: .clothes),
        ChecklistItem(name: "Gloves", category: .clothes),
        ChecklistItem(name: "Hat", category: .clothes),
        // Safety
        ChecklistItem(name: "Ice picks", category: .safety),
        ChecklistItem(name: "First aid kit", category: .safety),
        ChecklistItem(name: "Rope", category: .safety),
        ChecklistItem(name: "Whistle", category: .safety),
        ChecklistItem(name: "Phone/GPS", category: .safety)
    ]
    
    static let summerFishingItems: [ChecklistItem] = [
        // Gear
        ChecklistItem(name: "Fishing rod", category: .gear),
        ChecklistItem(name: "Tackle box", category: .gear),
        ChecklistItem(name: "Bait", category: .gear),
        ChecklistItem(name: "Cooler", category: .gear),
        ChecklistItem(name: "Net", category: .gear),
        // Clothes
        ChecklistItem(name: "Hat/cap", category: .clothes),
        ChecklistItem(name: "Sunglasses", category: .clothes),
        ChecklistItem(name: "Light clothing", category: .clothes),
        ChecklistItem(name: "Water shoes", category: .clothes),
        // Safety
        ChecklistItem(name: "Sunscreen", category: .safety),
        ChecklistItem(name: "First aid kit", category: .safety),
        ChecklistItem(name: "Water bottle", category: .safety),
        ChecklistItem(name: "Phone", category: .safety),
        ChecklistItem(name: "Life jacket", category: .safety)
    ]
}
