import SwiftUI
import CoreData

struct CoursesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var goodNotesService: GoodNotesService
    
    @State private var searchText = ""
    @State private var showingAddCourse = false
    @State private var selectedFilter: CourseFilter = .all
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Course.courseName, ascending: true)],
        animation: .default)
    private var classes: FetchedResults<Course>
    
    var filteredClasses: [Course] {
        let filtered = classes.filter { course in
            if !searchText.isEmpty {
                return (course.courseName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (course.courseCode?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            return true
        }
        
        switch selectedFilter {
        case .all:
            return filtered
        case .lecture:
            return filtered // All courses are lectures by default
        case .tutorial:
            return filtered // All courses are lectures by default
        case .lab:
            return filtered // All courses are lectures by default
        case .studio:
            return filtered // All courses are lectures by default
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                // Courses List
                coursesList
            }
            .navigationTitle("Courses")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCourse = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCourse) {
                AddCourseView()
            }
        }
    }
    
    // MARK: - Search and Filter Bar
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search courses...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CourseFilter.allCases, id: \.self) { filter in
                        FilterPill(
                            title: filter.title,
                            count: countForFilter(filter),
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Courses List
    private var coursesList: some View {
        Group {
            if filteredClasses.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredClasses, id: \.id) { course in
                        NavigationLink(destination: CourseDetailView(course: course)) {
                            CourseRow(course: course)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "graduationcap")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(emptyStateSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add Course") {
                showingAddCourse = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Methods
    private func countForFilter(_ filter: CourseFilter) -> Int {
        return classes.count
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "No courses yet"
        case .lecture:
            return "No lectures"
        case .tutorial:
            return "No tutorials"
        case .lab:
            return "No labs"
        case .studio:
            return "No studios"
        }
    }
    
    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .all:
            return "Add your first course to get started"
        case .lecture:
            return "No lecture courses found"
        case .tutorial:
            return "No tutorial courses found"
        case .lab:
            return "No lab courses found"
        case .studio:
            return "No studio courses found"
        }
    }
}

// MARK: - Course Filter
enum CourseFilter: CaseIterable {
    case all, lecture, tutorial, lab, studio
    
    var title: String {
        switch self {
        case .all: return "All"
        case .lecture: return "Lectures"
        case .tutorial: return "Tutorials"
        case .lab: return "Labs"
        case .studio: return "Studios"
        }
    }
}

// MARK: - Course Row
struct CourseRow: View {
    let course: Course
    @EnvironmentObject var goodNotesService: GoodNotesService
    
    var body: some View {
        HStack(spacing: 12) {
            // Course Icon
            VStack {
                Image(systemName: "graduationcap.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .frame(width: 40)
            
            // Course Details
            VStack(alignment: .leading, spacing: 4) {
                Text(course.courseName ?? "Unknown Course")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let courseCode = course.courseCode {
                        Text(courseCode)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Quick Stats
                HStack(spacing: 12) {
                    Label("\(goodNotesService.getNotebooks(for: course).count)", systemImage: "book")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Label("\(course.gradesArray.count)", systemImage: "chart.bar")
                        .font(.caption2)
                        .foregroundColor(.green)
                    
                    Label("\(course.tasksArray.count)", systemImage: "checklist")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Course View
struct AddCourseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var courseName = ""
    @State private var courseCode = ""
    @State private var classType = "Lecture"
    @State private var room = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600) // 1 hour later
    @State private var professorName = ""
    @State private var professorEmail = ""
    
    private let classTypes = ["Lecture", "Tutorial", "Lab", "Studio"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Course Information") {
                    TextField("Course Name", text: $courseName)
                    TextField("Course Code", text: $courseCode)
                    
                    Picker("Class Type", selection: $classType) {
                        ForEach(classTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                
                Section("Schedule") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    TextField("Room", text: $room)
                }
                
                Section("Professor") {
                    TextField("Professor Name", text: $professorName)
                    TextField("Professor Email", text: $professorEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCourse()
                    }
                    .disabled(courseName.isEmpty)
                }
            }
        }
    }
    
    private func saveCourse() {
        let newCourse = Course(context: viewContext)
        newCourse.id = UUID()
        newCourse.courseName = courseName
        newCourse.courseCode = courseCode
        newCourse.createdAt = Date()
        newCourse.updatedAt = Date()
        
        // Create class slot
        let newSlot = ClassSlot(context: viewContext)
        newSlot.id = UUID()
        newSlot.slotType = classType
        newSlot.room = room
        newSlot.startTime = startTime
        newSlot.endTime = endTime
        newSlot.course = newCourse
        
        // Create instructor if name is provided
        if !professorName.isEmpty {
            let instructor = Instructor(context: viewContext)
            instructor.id = UUID()
            instructor.name = professorName
            instructor.email = professorEmail.isEmpty ? nil : professorEmail
            newSlot.instructor = instructor
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving course: \(error)")
        }
    }
}

// MARK: - Preview
struct CoursesView_Previews: PreviewProvider {
    static var previews: some View {
        CoursesView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(GoodNotesService())
    }
}
