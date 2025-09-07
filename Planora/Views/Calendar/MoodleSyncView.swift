import SwiftUI
import CoreData

struct MoodleSyncView: View {
    @EnvironmentObject var moodleService: MoodleService
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingSetup = false
    @State private var syncProgress: SyncProgress = .idle
    @State private var syncResults = SyncResults()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !moodleService.isAuthenticated {
                    moodleSetupView
                } else {
                    syncOptionsView
                }
            }
            .padding()
            .navigationTitle("Moodle Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSetup) {
                MoodleSetupView()
            }
        }
    }
    
    // MARK: - Moodle Setup View
    private var moodleSetupView: some View {
        VStack(spacing: 20) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Connect to Moodle")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Sync your classes, assignments, and grades from Moodle to keep everything organized in one place.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Setup Moodle Connection") {
                showingSetup = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Sync Options View
    private var syncOptionsView: some View {
        VStack(spacing: 20) {
            // Connection Status
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected to Moodle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Sync Options
            VStack(spacing: 12) {
                SyncOptionCard(
                    title: "Classes",
                    subtitle: "Import course schedule and details",
                    icon: "graduationcap.fill",
                    color: .blue,
                    isEnabled: true
                ) {
                    syncClasses()
                }
                
                SyncOptionCard(
                    title: "Assignments",
                    subtitle: "Import upcoming deadlines and tasks",
                    icon: "checklist",
                    color: .orange,
                    isEnabled: true
                ) {
                    syncAssignments()
                }
                
                SyncOptionCard(
                    title: "Grades",
                    subtitle: "Import current grades and scores",
                    icon: "chart.bar.fill",
                    color: .green,
                    isEnabled: true
                ) {
                    syncGrades()
                }
            }
            
            // Sync All Button
            Button("Sync All") {
                syncAll()
            }
            .buttonStyle(.borderedProminent)
            .disabled(syncProgress != .idle)
            
            // Progress View
            if syncProgress != .idle {
                syncProgressView
            }
            
            // Results View
            if syncProgress == .completed {
                syncResultsView
            }
            
            Spacer()
        }
    }
    
    // MARK: - Sync Progress View
    private var syncProgressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(syncProgressMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Sync Results View
    private var syncResultsView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Sync Completed")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ResultRow(
                    title: "Classes",
                    count: syncResults.classesCount,
                    icon: "graduationcap.fill",
                    color: .blue
                )
                
                ResultRow(
                    title: "Assignments",
                    count: syncResults.assignmentsCount,
                    icon: "checklist",
                    color: .orange
                )
                
                ResultRow(
                    title: "Grades",
                    count: syncResults.gradesCount,
                    icon: "chart.bar.fill",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Methods
    private func syncClasses() {
        syncProgress = .syncingClasses
                    _Concurrency.Task {
            await moodleService.syncAll()
            DispatchQueue.main.async {
                syncProgress = .completed
                syncResults.classesCount = 5 // Example count
            }
        }
    }
    
    private func syncAssignments() {
        syncProgress = .syncingAssignments
                    _Concurrency.Task {
            await moodleService.syncAll()
            DispatchQueue.main.async {
                syncProgress = .completed
                syncResults.assignmentsCount = 8 // Example count
            }
        }
    }
    
    private func syncGrades() {
        syncProgress = .syncingGrades
                    _Concurrency.Task {
            await moodleService.syncAll()
            DispatchQueue.main.async {
                syncProgress = .completed
                syncResults.gradesCount = 12 // Example count
            }
        }
    }
    
    private func syncAll() {
        syncProgress = .syncingAll
                    _Concurrency.Task {
            await moodleService.syncAll()
            DispatchQueue.main.async {
                syncProgress = .completed
                syncResults.classesCount = 5
                syncResults.assignmentsCount = 8
                syncResults.gradesCount = 12
            }
        }
    }
    
    private var syncProgressMessage: String {
        switch syncProgress {
        case .idle:
            return ""
        case .syncingClasses:
            return "Syncing classes..."
        case .syncingAssignments:
            return "Syncing assignments..."
        case .syncingGrades:
            return "Syncing grades..."
        case .syncingAll:
            return "Syncing all data..."
        case .completed:
            return "Sync completed!"
        }
    }
}

// MARK: - Supporting Types
enum SyncProgress {
    case idle, syncingClasses, syncingAssignments, syncingGrades, syncingAll, completed
}

struct SyncResults {
    var classesCount = 0
    var assignmentsCount = 0
    var gradesCount = 0
}

// MARK: - Sync Option Card
struct SyncOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Result Row
struct ResultRow: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct MoodleSyncView_Previews: PreviewProvider {
    static var previews: some View {
        MoodleSyncView()
            .environmentObject(MoodleService())
    }
}
