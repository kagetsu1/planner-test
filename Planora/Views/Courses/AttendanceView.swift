import SwiftUI
import CoreData

struct AttendanceView: View {
    let slot: ClassSlot
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var attendanceStatus = "Present"
    @State private var showingAddAttendance = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let attendanceStatuses = ["Present", "Absent", "Late", "Excused"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                attendanceHeader
                
                // Attendance List
                attendanceList
            }
            .navigationTitle("Attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mark") {
                        showingAddAttendance = true
                    }
                }
            }
            .sheet(isPresented: $showingAddAttendance) {
                AddAttendanceView(slot: slot, selectedDate: selectedDate)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Attendance Header
    private var attendanceHeader: some View {
        VStack(spacing: 16) {
            // Class Info
            VStack(spacing: 8) {
                Text(slot.course?.courseName ?? "Unknown Course")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(slot.slotType ?? "Class")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let instructor = slot.instructor {
                    Text("with \(instructor.name ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Attendance Stats
            HStack(spacing: 20) {
                AttendanceStatCard(
                    title: "Present",
                    count: presentCount,
                    color: .green
                )
                
                AttendanceStatCard(
                    title: "Absent",
                    count: absentCount,
                    color: .red
                )
                
                AttendanceStatCard(
                    title: "Late",
                    count: lateCount,
                    color: .orange
                )
                
                AttendanceStatCard(
                    title: "Total",
                    count: totalAttendanceCount,
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Attendance List
    private var attendanceList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let attendanceRecords = slot.attendanceArray
                
                if attendanceRecords.isEmpty {
                    emptyAttendanceView
                } else {
                    ForEach(attendanceRecords, id: \.id) { attendance in
                        AttendanceRow(attendance: attendance) {
                            deleteAttendance(attendance)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    private var emptyAttendanceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No attendance records")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Mark your attendance for this class slot")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Mark Attendance") {
                showingAddAttendance = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helper Methods
    private func deleteAttendance(_ attendance: Attendance) {
        viewContext.delete(attendance)
        
        do {
            try viewContext.save()
        } catch {
            errorMessage = "Failed to delete attendance: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private var presentCount: Int {
        slot.attendanceArray.filter { $0.status == "Present" }.count
    }
    
    private var absentCount: Int {
        slot.attendanceArray.filter { $0.status == "Absent" }.count
    }
    
    private var lateCount: Int {
        slot.attendanceArray.filter { $0.status == "Late" }.count
    }
    
    private var totalAttendanceCount: Int {
        slot.attendanceArray.count
    }
}

// MARK: - Attendance Stat Card
struct AttendanceStatCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Attendance Row
struct AttendanceRow: View {
    let attendance: Attendance
    let onDelete: () -> Void
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                if let date = attendance.date {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if let markedAt = attendance.markedAt {
                    Text("Marked at \(markedAt, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(attendance.status ?? "Unknown")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
            
            Button(action: { showingDeleteAlert = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .alert("Delete Attendance", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this attendance record?")
        }
    }
    
    private var statusColor: Color {
        switch attendance.status?.lowercased() {
        case "present": return .green
        case "absent": return .red
        case "late": return .orange
        case "excused": return .blue
        default: return .gray
        }
    }
}

// MARK: - Add Attendance View
struct AddAttendanceView: View {
    let slot: ClassSlot
    let selectedDate: Date
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var attendanceStatus = "Present"
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let attendanceStatuses = ["Present", "Absent", "Late", "Excused"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Attendance Details") {
                    DatePicker("Date", selection: .constant(selectedDate), displayedComponents: .date)
                        .disabled(true)
                    
                    Picker("Status", selection: $attendanceStatus) {
                        ForEach(attendanceStatuses, id: \.self) { status in
                            HStack {
                                Circle()
                                    .fill(statusColor(for: status))
                                    .frame(width: 12, height: 12)
                                Text(status)
                            }
                            .tag(status)
                        }
                    }
                }
                
                Section {
                    Button("Mark Attendance") {
                        addAttendance()
                    }
                }
            }
            .navigationTitle("Mark Attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addAttendance() {
        let newAttendance = Attendance(context: viewContext)
        newAttendance.id = UUID()
        newAttendance.date = selectedDate
        newAttendance.status = attendanceStatus
        newAttendance.markedAt = Date()
        newAttendance.slot = slot
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save attendance: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "present": return .green
        case "absent": return .red
        case "late": return .orange
        case "excused": return .blue
        default: return .gray
        }
    }
}

// MARK: - Extensions
extension ClassSlot {
    var attendanceArray: [Attendance] {
        let set = attendance as? Set<Attendance> ?? []
        return Array(set).sorted { attendance1, attendance2 in
            guard let date1 = attendance1.date, let date2 = attendance2.date else { return false }
            return date1 > date2
        }
    }
}

struct AttendanceView_Previews: PreviewProvider {
    static var previews: some View {
        AttendanceView(slot: ClassSlot())
            .environment(\.managedObjectContext, DataController().container.viewContext)
    }
}
