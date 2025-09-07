import SwiftUI
import CoreData

struct AddHabitView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationService: NotificationService
    
    @State private var name = ""
    @State private var description = ""
    @State private var frequency = "Daily"
    @State private var targetDays = 1
    @State private var reminderTime = Date()
    @State private var addReminder = true
    @State private var color = Color.blue
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let frequencies = ["Daily", "Weekly", "Monthly"]
    private let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .indigo, .teal]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Habit Details") {
                    TextField("Habit Name", text: $name)
                    
                    if #available(iOS 16.0, *) {
                        TextField("Description (Optional)", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        TextField("Description (Optional)", text: $description)
                            .lineLimit(3)
                    }
                }
                
                Section("Frequency") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(frequencies, id: \.self) { freq in
                            Text(freq).tag(freq)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if frequency == "Weekly" {
                        Stepper("Target: \(targetDays) day\(targetDays == 1 ? "" : "s") per week", value: $targetDays, in: 1...7)
                    } else if frequency == "Monthly" {
                        Stepper("Target: \(targetDays) day\(targetDays == 1 ? "" : "s") per month", value: $targetDays, in: 1...31)
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colors, id: \.self) { colorOption in
                            Circle()
                                .fill(colorOption)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: color == colorOption ? 3 : 0)
                                )
                                .onTapGesture {
                                    color = colorOption
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Reminder") {
                    Toggle("Daily Reminder", isOn: $addReminder)
                    
                    if addReminder {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section {
                    Button("Add Habit") {
                        addHabit()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle("Add Habit")
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
    
    private func addHabit() {
        guard !name.isEmpty else {
            errorMessage = "Please enter a habit name"
            showingError = true
            return
        }
        
        let newHabit = Habit(context: viewContext)
        newHabit.id = UUID()
        newHabit.name = name
        newHabit.frequency = frequency
        newHabit.targetCount = Int32(targetDays)
        newHabit.color = color.toHex()
        newHabit.createdAt = Date()
        newHabit.updatedAt = Date()
        
        do {
            try viewContext.save()
            
            // Add reminder if requested
            if addReminder {
                notificationService.scheduleHabitReminder(for: newHabit)
            }
            
            dismiss()
        } catch {
            errorMessage = "Failed to save habit: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Color Extension
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "#%06x", rgb)
    }
    
    static func fromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct AddHabitView_Previews: PreviewProvider {
    static var previews: some View {
        AddHabitView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
            .environmentObject(NotificationService())
    }
}
