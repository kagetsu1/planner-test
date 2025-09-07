import SwiftUI
import CoreData
import Charts

struct GradeDetailsView: View {
    let course: Course
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeframe: Timeframe = .semester
    @State private var showingAddGrade = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Class Header
                classHeader
                
                // Grade Statistics
                gradeStatistics
                
                // Grade Distribution Chart
                gradeDistributionChart
                
                // Performance by Category
                performanceByCategory
                
                // Grades List
                gradesList
            }
            .padding()
        }
        .navigationTitle(course.courseName ?? "Course Grades")
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
    }
    
    // MARK: - Class Header
    private var classHeader: some View {
        VStack(spacing: 12) {
            Text(course.courseName ?? "Unknown Course")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            if let courseCode = course.courseCode {
                Text(courseCode)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // TODO: Add course type if needed
            Text("Course")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Grade Statistics
    private var gradeStatistics: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Grade Statistics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                GradeStatCard(
                    title: "Overall GPA",
                    value: String(format: "%.2f", overallGPA),
                    subtitle: letterGrade,
                    color: gpaColor
                )
                
                GradeStatCard(
                    title: "Total Assignments",
                    value: "\(grades.count)",
                    subtitle: "graded",
                    color: .blue
                )
                
                GradeStatCard(
                    title: "Highest Grade",
                    value: String(format: "%.1f%%", highestGrade),
                    subtitle: "best performance",
                    color: .green
                )
                
                GradeStatCard(
                    title: "Lowest Grade",
                    value: String(format: "%.1f%%", lowestGrade),
                    subtitle: "needs improvement",
                    color: .red
                )
            }
        }
    }
    
    // MARK: - Grade Distribution Chart
    private var gradeDistributionChart: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Grade Distribution")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if #available(iOS 16.0, *) {
                Chart(gradeDistributionData) { item in
                    BarMark(
                        x: .value("Range", item.range),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(item.color)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
            } else {
                Text("Grade distribution charts require iOS 16+")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Performance by Category
    private var performanceByCategory: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Performance by Category")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(categoryPerformance, id: \.category) { performance in
                    CategoryPerformanceRow(performance: performance)
                }
            }
        }
    }
    
    // MARK: - Grades List
    private var gradesList: some View {
        VStack(spacing: 16) {
            HStack {
                Text("All Grades")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Text("\(grades.count) assignments")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(grades, id: \.id) { grade in
                    GradeDetailRow(grade: grade)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var grades: [Grade] {
        return course.gradesArray
    }
    
    private var overallGPA: Double {
        guard !grades.isEmpty else { return 0.0 }
        let totalPoints = grades.reduce(0) { $0 + $1.score }
        let maxPoints = grades.reduce(0) { $0 + $1.totalPoints }
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
        case 3.5...: return .green
        case 3.0..<3.5: return .blue
        case 2.5..<3.0: return .orange
        default: return .red
        }
    }
    
    private var highestGrade: Double {
        guard !grades.isEmpty else { return 0.0 }
        return grades.map { ($0.score / $0.totalPoints) * 100 }.max() ?? 0.0
    }
    
    private var lowestGrade: Double {
        guard !grades.isEmpty else { return 0.0 }
        return grades.map { ($0.score / $0.totalPoints) * 100 }.min() ?? 0.0
    }
    
    private var classTypeColor: Color {
        // TODO: Add course type logic if needed
        return .blue
    }
    
    private var gradeDistributionData: [GradeDistributionDetailItem] {
        let percentages = grades.map { ($0.score / $0.totalPoints) * 100 }
        
        var distribution = [
            GradeDistributionDetailItem(range: "90-100", count: 0, color: .green),
            GradeDistributionDetailItem(range: "80-89", count: 0, color: .blue),
            GradeDistributionDetailItem(range: "70-79", count: 0, color: .orange),
            GradeDistributionDetailItem(range: "60-69", count: 0, color: .red),
            GradeDistributionDetailItem(range: "0-59", count: 0, color: .gray)
        ]
        
        for percentage in percentages {
            switch percentage {
            case 90...: distribution[0].count += 1
            case 80..<90: distribution[1].count += 1
            case 70..<80: distribution[2].count += 1
            case 60..<70: distribution[3].count += 1
            default: distribution[4].count += 1
            }
        }
        
        return distribution
    }
    
    private var categoryPerformance: [CategoryPerformance] {
        let categories = Set(grades.compactMap { $0.assignmentType })
        return categories.map { category in
            let categoryGrades = grades.filter { $0.assignmentType == category }
            let average = categoryGrades.reduce(0.0) { $0 + ($1.score / $1.totalPoints) * 100 } / Double(categoryGrades.count)
            return CategoryPerformance(category: category, average: average, count: categoryGrades.count)
        }.sorted { $0.average > $1.average }
    }
}

// MARK: - Supporting Types
// Note: CategoryPerformance is defined in GradesView.swift to avoid duplication

struct GradeDistributionDetailItem: Identifiable {
    let id = UUID()
    let range: String
    var count: Int
    let color: Color
}

// MARK: - Stat Card
struct GradeStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Category Performance Row
struct CategoryPerformanceRow: View {
    let performance: CategoryPerformance
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(performance.category)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(performance.count) assignment\(performance.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f%%", performance.average))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(gradeColor(for: performance.average))
                
                Text("average")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func gradeColor(for percentage: Double) -> Color {
        switch percentage {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Grade Detail Row
struct GradeDetailRow: View {
    let grade: Grade
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(grade.name ?? "Unknown Assignment")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let type = grade.assignmentType {
                    Text(type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f%%", percentage))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(gradeColor)
                
                Text("\(Int(grade.score))/\(Int(grade.totalPoints))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var percentage: Double {
        guard grade.totalPoints > 0 else { return 0 }
        return (grade.score / grade.totalPoints) * 100
    }
    
    private var gradeColor: Color {
        switch percentage {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }
}

struct GradeDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        GradeDetailsView(course: Course())
            .environment(\.managedObjectContext, DataController().container.viewContext)
    }
}
