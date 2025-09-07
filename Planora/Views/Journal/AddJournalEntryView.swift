import SwiftUI
import CoreData

struct AddJournalEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedMood: MoodType = .okay
    @State private var tags = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let moods: [MoodType] = [.great, .good, .okay, .bad, .terrible]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with mood selector
                moodSelector
                
                // Content area
                contentArea
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(title.isEmpty && content.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Mood Selector
    private var moodSelector: some View {
        VStack(spacing: 16) {
            Text("How are you feeling today?")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                ForEach(moods, id: \.self) { mood in
                    VStack(spacing: 8) {
                        Button(action: { selectedMood = mood }) {
                            Text(mood.emoji)
                                .font(.system(size: 30))
                                .foregroundColor(selectedMood == mood ? mood.color : .secondary)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(selectedMood == mood ? mood.color.opacity(0.1) : Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(mood.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(selectedMood == mood ? mood.color : .secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Content Area
    private var contentArea: some View {
        VStack(spacing: 0) {
            // Title field
            TextField("Entry Title (Optional)", text: $title)
                .font(.title2)
                .modifier(iOS16FontWeight(.semibold))
                .padding()
                .background(Color(.systemBackground))
            
            Divider()
            
            // Content field
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("What's on your mind?")
                        .font(.subheadline)
                        .modifier(iOS16FontWeight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                
                TextEditor(text: $content)
                    .font(.body)
                    .padding(.horizontal)
                    .background(Color(.systemBackground))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Tags field
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags (Optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                TextField("e.g., study, stress, achievement", text: $tags)
                    .font(.body)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Save Entry
    private func saveEntry() {
        guard !content.isEmpty else {
            errorMessage = "Please write something in your journal entry"
            showingError = true
            return
        }
        
        let newEntry = JournalEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.title = title.isEmpty ? nil : title
        newEntry.content = content
        newEntry.mood = selectedMood.rawValue
        newEntry.tags = tags.isEmpty ? nil : tags
        newEntry.createdAt = Date()
        newEntry.updatedAt = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save entry: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Mood Type
// Note: MoodType is defined in JournalView.swift to avoid duplication

struct AddJournalEntryView_Previews: PreviewProvider {
    static var previews: some View {
        AddJournalEntryView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
    }
}
