import SwiftUI
import CoreData

struct AddInstructorView: View {
    let course: Course
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role = "Professor"
    @State private var officeHours = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let roles = ["Professor", "TA", "Instructor", "Lecturer", "Adjunct"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Instructor Details") {
                    TextField("Name", text: $name)
                    
                    Picker("Role", selection: $role) {
                        ForEach(roles, id: \.self) { role in
                            Text(role).tag(role)
                        }
                    }
                }
                
                Section("Contact Information") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("Office Hours") {
                    TextField("Office Hours", text: $officeHours)
                        .placeholder(when: officeHours.isEmpty) {
                            Text("e.g., Mon/Wed 2-4pm, or by appointment")
                                .foregroundColor(.secondary)
                        }
                }
                
                Section {
                    Button("Add Instructor") {
                        addInstructor()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle("Add Instructor")
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
    
    private func addInstructor() {
        guard !name.isEmpty else {
            errorMessage = "Please enter an instructor name"
            showingError = true
            return
        }
        
        let newInstructor = Instructor(context: viewContext)
        newInstructor.id = UUID()
        newInstructor.name = name
        newInstructor.email = email.isEmpty ? nil : email
        newInstructor.phone = phone.isEmpty ? nil : phone
        newInstructor.role = role
        newInstructor.officeHours = officeHours.isEmpty ? nil : officeHours
        
        // Add to the course
        newInstructor.addToCourses(course)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save instructor: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// Note: placeholder extension is defined in MoodleSetupView.swift to avoid duplication

struct AddInstructorView_Previews: PreviewProvider {
    static var previews: some View {
        AddInstructorView(course: Course())
            .environment(\.managedObjectContext, DataController().container.viewContext)
    }
}
