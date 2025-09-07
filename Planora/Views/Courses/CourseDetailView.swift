import SwiftUI
import CoreData

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var goodNotesService: GoodNotesService
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedTab = 0
    @State private var showingAddNotebook = false
    @State private var selectedNotebook: GoodNotesNotebook?
    @State private var showingNotebookBrowser = false
    @State private var showingAddSlot = false
    @State private var showingAddInstructor = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Course Header
            courseHeader
            
            // Tab Selector
            tabSelector
            
            // Tab Content
            TabView(selection: $selectedTab) {
                // Overview Tab
                courseOverview
                    .tag(0)
                
                // Schedule Tab
                scheduleTab
                    .tag(1)
                
                // Notebooks Tab
                notebooksTab
                    .tag(2)
                
                // Grades Tab
                gradesTab
                    .tag(3)
                
                // Tasks Tab
                tasksTab
                    .tag(4)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle(course.courseName ?? "Course")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingAddSlot = true }) {
                        Label("Add Class Slot", systemImage: "clock.badge.plus")
                    }
                    
                    Button(action: { showingAddInstructor = true }) {
                        Label("Add Instructor", systemImage: "person.badge.plus")
                    }
                    
                    Button(action: { showingAddNotebook = true }) {
                        Label("Add Notebook", systemImage: "book.badge.plus")
                    }
                    
                    Button(action: { }) {
                        Label("Add Task", systemImage: "plus.circle")
                    }
                    
                    Button(action: { }) {
                        Label("Add Grade", systemImage: "chart.bar.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddNotebook) {
            AddNotebookView(course: course)
        }
        .sheet(isPresented: $showingNotebookBrowser) {
            if let notebook = selectedNotebook {
                NotebookBrowserView(notebook: notebook)
            }
        }
        .sheet(isPresented: $showingAddSlot) {
            AddClassSlotView(course: course)
        }
        .sheet(isPresented: $showingAddInstructor) {
            AddInstructorView(course: course)
        }
    }
    
    // MARK: - Course Header
    private var courseHeader: some View {
        VStack(spacing: 16) {
            // Course Info
            VStack(spacing: 8) {
                Text(course.courseName ?? "Unknown Course")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(course.courseCode ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Quick Stats
            HStack(spacing: 20) {
                StatItem(
                    title: "Slots",
                    value: "\(course.slotsArray.count)",
                    icon: "clock.fill",
                    color: .blue
                )
                
                StatItem(
                    title: "Instructors",
                    value: "\(course.instructorsArray.count)",
                    icon: "person.2.fill",
                    color: .green
                )
                
                StatItem(
                    title: "Notebooks",
                    value: "\(goodNotesService.getNotebooks(for: course).count)",
                    icon: "book.fill",
                    color: .purple
                )
                
                StatItem(
                    title: "Grades",
                    value: "\(course.gradesArray.count)",
                    icon: "chart.bar.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(tabItems, id: \.title) { tab in
                Button(action: { selectedTab = tab.index }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16))
                        
                        Text(tab.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab.index ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Rectangle()
                            .fill(selectedTab == tab.index ? Color.blue.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Course Overview
    private var courseOverview: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Instructors Info
                instructorsCard
                
                // Next Class
                nextClassCard
                
                // Recent Activity
                recentActivityCard
            }
            .padding()
        }
    }
    
    // MARK: - Schedule Tab
    private var scheduleTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let slots = course.slotsArray
                
                if slots.isEmpty {
                    emptyScheduleView
                } else {
                    ForEach(slots, id: \.id) { slot in
                        ClassSlotCard(slot: slot)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Notebooks Tab
    private var notebooksTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let notebooks = goodNotesService.getNotebooks(for: course)
                
                if notebooks.isEmpty {
                    emptyNotebooksView
                } else {
                    ForEach(notebooks) { notebook in
                        Button(action: {
                            selectedNotebook = notebook
                            showingNotebookBrowser = true
                        }) {
                            HStack {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.blue)
                                Text(notebook.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Grades Tab
    private var gradesTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let grades = course.gradesArray
                
                if grades.isEmpty {
                    emptyGradesView
                } else {
                    ForEach(grades, id: \.id) { grade in
                        GradeDetailRow(grade: grade)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Tasks Tab
    private var tasksTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let tasks = course.tasksArray
                
                if tasks.isEmpty {
                    emptyTasksView
                } else {
                    ForEach(tasks, id: \.id) { task in
                        TaskRow(task: task) {
                            // Toggle task completion
                            task.completed.toggle()
                            try? viewContext.save()
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Supporting Views
    private var instructorsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.green)
                Text("Instructors")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(course.instructorsArray, id: \.objectID) { instructor in
                    InstructorRow(instructor: instructor)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var nextClassCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text("Next Class")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let nextSlot = getNextClassSlot() {
                NextClassRow(slot: nextSlot)
            } else {
                Text("No upcoming classes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.purple)
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("No recent activity")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var emptyScheduleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No class slots yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add class slots to set up your schedule")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add Class Slot") {
                showingAddSlot = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
    
    private var emptyNotebooksView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No notebooks yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add your GoodNotes notebooks to keep them organized with this course")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add Notebook") {
                showingAddNotebook = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
    
    private var emptyGradesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No grades yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add grades to track your performance in this course")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    private var emptyTasksView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No tasks yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add tasks and assignments for this course")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helper Methods
    private func getNextClassSlot() -> ClassSlot? {
        let now = Date()
        return course.slotsArray
            .filter { slot in
                guard let startTime = slot.startTime else { return false }
                return startTime > now
            }
            .sorted { slot1, slot2 in
                guard let time1 = slot1.startTime, let time2 = slot2.startTime else { return false }
                return time1 < time2
            }
            .first
    }
    
    private var tabItems: [TabItem] {
        [
            TabItem(title: "Overview", icon: "house.fill", index: 0),
            TabItem(title: "Schedule", icon: "clock.fill", index: 1),
            TabItem(title: "Notebooks", icon: "book.fill", index: 2),
            TabItem(title: "Grades", icon: "chart.bar.fill", index: 3),
            TabItem(title: "Tasks", icon: "checklist", index: 4)
        ]
    }
}

// MARK: - Supporting Types
struct TabItem {
    let title: String
    let icon: String
    let index: Int
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Instructor Row
struct InstructorRow: View {
    let instructor: Instructor
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(instructor.name ?? "Unknown Instructor")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let role = instructor.role {
                        Text(role)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(roleColor.opacity(0.1))
                            .foregroundColor(roleColor)
                            .clipShape(Capsule())
                    }
                }
                
                if let email = instructor.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let officeHours = instructor.officeHours {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Office Hours")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(officeHours)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var roleColor: Color {
        switch instructor.role?.lowercased() {
        case "professor": return .blue
        case "ta": return .green
        case "instructor": return .orange
        default: return .gray
        }
    }
}

// MARK: - Next Class Row
struct NextClassRow: View {
    let slot: ClassSlot
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.slotType ?? "Class")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let instructor = slot.instructor {
                    Text("with \(instructor.name ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let startTime = slot.startTime {
                    Text(startTime, style: .time)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if let room = slot.room {
                    Text("Room \(room)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Class Slot Card
struct ClassSlotCard: View {
    let slot: ClassSlot
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAttendance = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(slot.slotType ?? "Class")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let instructor = slot.instructor {
                        Text("Instructor: \(instructor.name ?? "Unknown")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { showingAttendance = true }) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    if let startTime = slot.startTime, let endTime = slot.endTime {
                        Text("\(startTime, style: .time) - \(endTime, style: .time)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(dayOfWeekString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Room")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(slot.room ?? "TBD")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingAttendance) {
            AttendanceView(slot: slot)
        }
    }
    
    private var dayOfWeekString: String {
        let days = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let dayIndex = Int(slot.dayOfWeek)
        return dayIndex >= 1 && dayIndex <= 7 ? days[dayIndex] : "Unknown"
    }
}


