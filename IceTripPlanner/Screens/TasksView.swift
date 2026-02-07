
import SwiftUI

struct TasksView: View {
    let trip: Trip
    @StateObject private var viewModel = TripViewModel()
    @State private var showingAddTask = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress Card
                if !trip.tasks.isEmpty {
                    taskProgressCard
                }
                
                // Tasks by Priority
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    let priorityTasks = trip.tasks.filter { $0.priority == priority }
                    if !priorityTasks.isEmpty {
                        prioritySection(priority: priority, tasks: priorityTasks)
                    }
                }
                
                // Empty State
                if trip.tasks.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.clipboard",
                        title: "No Tasks Yet",
                        description: "Add tasks to prepare for your trip"
                    )
                    .padding(.top, 50)
                }
                
                // Add Task Button
                Button(action: { showingAddTask = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Task")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "4A90E2"))
                    .cornerRadius(15)
                    .shadow(color: Color(hex: "4A90E2").opacity(0.3), radius: 10, y: 5)
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
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(trip: trip)
        }
    }
    
    private var taskProgressCard: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Task Progress")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1E3A5F"))
                    
                    Text("\(completedTaskCount) of \(trip.tasks.count) completed")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color(hex: "4A90E2").opacity(0.2), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(trip.taskProgress))
                        .stroke(
                            Color(hex: "4CAF50"),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: trip.taskProgress)
                    
                    Text("\(Int(trip.taskProgress * 100))%")
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
    
    private func prioritySection(priority: TaskPriority, tasks: [TripTask]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: priority.icon)
                    .foregroundColor(Color(hex: priority.color))
                Text(priority.rawValue + " Priority")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "1E3A5F"))
                
                Spacer()
                
                Text("\(tasks.filter { $0.isCompleted }.count)/\(tasks.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "1E3A5F").opacity(0.7))
            }
            
            VStack(spacing: 10) {
                ForEach(tasks) { task in
                    TaskRowView(
                        task: task,
                        onToggle: {
                            withAnimation(.spring()) {
                                viewModel.toggleTask(
                                    tripId: trip.id,
                                    taskId: task.id
                                )
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
        .padding(.horizontal)
    }
    
    private var completedTaskCount: Int {
        trip.tasks.filter { $0.isCompleted }.count
    }
}

// MARK: - Task Row View
struct TaskRowView: View {
    let task: TripTask
    var isCompact: Bool = false
    var onToggle: (() -> Void)? = nil
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            if let toggle = onToggle {
                toggle()
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }) {
            HStack(spacing: 15) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: task.priority.color).opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if task.isCompleted {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: task.priority.color))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3), value: isPressed)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "1E3A5F"))
                        .strikethrough(task.isCompleted)
                        .opacity(task.isCompleted ? 0.6 : 1.0)
                    
                    if !isCompact {
                        HStack(spacing: 10) {
                            // Priority badge
                            HStack(spacing: 4) {
                                Image(systemName: task.priority.icon)
                                    .font(.system(size: 10))
                                Text(task.priority.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: task.priority.color))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: task.priority.color).opacity(0.15))
                            .cornerRadius(8)
                            
                            // Deadline
                            if let deadline = task.deadline {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text(formattedDeadline(deadline))
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(Color(hex: "1E3A5F").opacity(0.6))
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private func formattedDeadline(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Add Task View
struct AddTaskView: View {
    let trip: Trip
    @StateObject private var viewModel = TripViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var taskTitle = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var hasDeadline = false
    @State private var deadline = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $taskTitle)
                    
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priority.icon)
                                Text(priority.rawValue)
                            }
                            .tag(priority)
                        }
                    }
                }
                
                Section(header: Text("Deadline")) {
                    Toggle("Set Deadline", isOn: $hasDeadline)
                    
                    if hasDeadline {
                        DatePicker(
                            "Deadline",
                            selection: $deadline,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addTask()
                    }
                    .disabled(taskTitle.isEmpty)
                }
            }
        }
    }
    
    private func addTask() {
        let newTask = TripTask(
            title: taskTitle,
            deadline: hasDeadline ? deadline : nil,
            priority: selectedPriority
        )
        viewModel.addTask(to: trip.id, task: newTask)
        presentationMode.wrappedValue.dismiss()
    }
}
