import SwiftUI
import CoreData

struct JournalEntryDetailView: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(entry.title ?? "Untitled Entry")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(entry.content ?? "")
                        .font(.body)
                    
                    if let tags = entry.tags, !tags.isEmpty {
                        Text("Tags: \(tags)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Entry Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
