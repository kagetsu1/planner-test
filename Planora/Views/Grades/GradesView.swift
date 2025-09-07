import SwiftUI
import CoreData
#if canImport(Charts)
import Charts
#endif

struct GradesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var moodleService: MoodleService
    
    @State private var showingAddGrade = false
    @State private var selectedClass: Course?
    @State private var selectedTimeframe: Timeframe = .semester
    @State private var showingGradeDetails = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Course.courseName, ascending: true)],
        animation: .default)
    private var classes: FetchedResults<Course>
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall GPA Card
                    overallGPACard
                    
                    // Timeframe Selector
                    timeframeSelector
                    
                    // Grade Distribution Chart
                    gradeDistributionChart
                    
                    // Performance by Category
                    performanceByCategory
                    
                    // Classes List
                    classesList
                }
                .padding()
            }
            .navigationTitle("Grades")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddGrade = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGrade) {
                AddGradeView()
            }
            .sheet(isPresented: $showingGradeDetails) {
                if let selectedClass = selectedClass {
                    GradeDetailsView(course: selectedClass)
                }
            }
        }
    }
    
    // MARK: - Overall GPA Card
    private var overallGPACard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall GPA")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.2f", overallGPA))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(gpaColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Letter Grade")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(letterGrade)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(gpaColor)
                }
            }
            
            // GPA Trend
            HStack {
                Text("Trend")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: gpaTrendIcon)
                        .foregroundColor(gpaTrendColor)
                    
                    Text(gpaTrendText)
                        .font(.caption)
                        .foregroundColor(gpaTrendColor)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Timeframe Selector
    private var timeframeSelector: some View {
        HStack(spacing: 0) {
            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                Button(action: { selectedTimeframe = timeframe }) {
                    Text(timeframe.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTimeframe == timeframe ? Color.blue : Color.clear)
                        )
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Grade Distribution Chart
    private var gradeDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grade Distribution")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart(gradeDistributionData) { item in
                    BarMark(
                        x: .value("Grade", item.letterGrade),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(by: .value("Grade", item.letterGrade))
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartForegroundStyleScale([
                    "A": .green,
                    "B": .blue,
                    "C": .orange,
                    "D": .red,
                    "F": .purple
                ])
            } else {
                Text("Grade distribution charts require iOS 16+")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Performance by Category
    private var performanceByCategory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance by Category")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(categoryPerformance, id: \.category) { performance in
                    CategoryPerformanceCard(performance: performance)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Classes List
    private var classesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Classes")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(classes, id: \.objectID) { classItem in
                ClassGradeRow(course: classItem) {
                    selectedClass = classItem
                    showingGradeDetails = true
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Computed Properties
    private var overallGPA: Double {
        let allGrades = classes.flatMap { $0.gradesArray }
        guard !allGrades.isEmpty else { return 0.0 }
        
        let totalPoints = allGrades.reduce(0.0) { $0 + $1.score }
        let maxPoints = allGrades.reduce(0.0) { $0 + $1.totalPoints }
        
        return maxPoints > 0 ? (totalPoints / maxPoints) * 4.0 : 0.0
    }
    
    private var letterGrade: String {
        switch overallGPA {
        case 3.7...: return "A"
        case 3.3..<3.7: return "A-"
        case 3.0..<3.3: return "B+"
        case 2.7..<3.0: return "B"
        case 2.3..<2.7: return "B-"
        case 2.0..<2.3: return "C+"
        case 1.7..<2.0: return "C"
        case 1.3..<1.7: return "C-"
        case 1.0..<1.3: return "D+"
        case 0.7..<1.0: return "D"
        default: return "F"
        }
    }
    
    private var gpaColor: Color {
        switch overallGPA {
        case 3.7...: return .green
        case 3.0..<3.7: return .blue
        case 2.0..<3.0: return .orange
        default: return .red
        }
    }
    
    private var gpaTrendIcon: String {
        // This would calculate trend based on recent grades
        return "arrow.up"
    }
    
    private var gpaTrendColor: Color {
        return .green
    }
    
    private var gpaTrendText: String {
        return "+0.15"
    }
    
    private var gradeDistributionData: [GradeDistributionItem] {
        let allGrades = classes.flatMap { $0.gradesArray }
        let gradeCounts: [String: [Grade]] = Dictionary(grouping: allGrades) { grade in
            let percentage = grade.totalPoints > 0 ? (grade.score / grade.totalPoints) * 100.0 : 0.0
            switch percentage {
            case 90...: return "A"
            case 80..<90: return "B"
            case 70..<80: return "C"
            case 60..<70: return "D"
            default: return "F"
            }
        }
        
        return ["A", "B", "C", "D", "F"].map { letter in
            GradeDistributionItem(letterGrade: letter, count: gradeCounts[letter]?.count ?? 0)
        }
    }
    
    private var categoryPerformance: [CategoryPerformance] {
        let allGrades = classes.flatMap { $0.gradesArray }
        let categoryGroups = Dictionary(grouping: allGrades) { $0.assignmentType ?? "Other" }
        
        return categoryGroups.map { category, grades in
            let totalScore = grades.reduce(0) { $0 + $1.score }
            let totalPoints = grades.reduce(0) { $0 + $1.totalPoints }
            let average = totalPoints > 0 ? (totalScore / totalPoints) * 100 : 0
            
            return CategoryPerformance(
                category: category,
                average: average,
                count: grades.count
            )
        }.sorted { $0.average > $1.average }
    }
}

// MARK: - Supporting Types
enum Timeframe: CaseIterable {
    case semester, year, allTime
    
    var title: String {
        switch self {
        case .semester: return "Semester"
        case .year: return "Year"
        case .allTime: return "All Time"
        }
    }
}

struct GradeDistributionItem: Identifiable {
    let id = UUID()
    let letterGrade: String
    let count: Int
}

struct CategoryPerformance {
    let category: String
    let average: Double
    let count: Int
}

// MARK: - Category Performance Card
struct CategoryPerformanceCard: View {
    let performance: CategoryPerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(performance.category)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            HStack {
                Text(String(format: "%.1f%%", performance.average))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(averageColor)
                
                Spacer()
                
                Text("\(performance.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var averageColor: Color {
        switch performance.average {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Class Grade Row
struct ClassGradeRow: View {
    let course: Course
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Class Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.courseName ?? "Unknown Course")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(course.courseCode ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Grade Info
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", classAverage))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(averageColor)
                    
                    Text("\(course.gradesArray.count) assignments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var classAverage: Double {
        let grades = course.gradesArray
        guard !grades.isEmpty else { return 0.0 }
        
        let totalScore = grades.reduce(0.0) { $0 + $1.score }
        let totalPoints = grades.reduce(0.0) { $0 + $1.totalPoints }
        
        return totalPoints > 0 ? (totalScore / totalPoints) * 100 : 0.0
    }
    
    private var averageColor: Color {
        switch classAverage {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }
}



// MARK: - Preview
struct GradesView_Previews: PreviewProvider {
    static var previews: some View {
        GradesView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(MoodleService())
    }
}
