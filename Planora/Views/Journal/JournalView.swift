import SwiftUI
import CoreData

struct JournalView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingAddEntry = false
    @State private var searchText = ""
    @State private var selectedFilter: JournalFilter = .all
    @State private var selectedEntry: JournalEntry?
    @State private var showingEntryDetails = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.createdAt, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<JournalEntry>
    
    var filteredEntries: [JournalEntry] {
        let filtered = entries.filter { entry in
            if !searchText.isEmpty {
                return (entry.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                       (entry.content?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            return true
        }
        
        switch selectedFilter {
        case .all:
            return filtered
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            return filtered.filter { entry in
                guard let entryDate = entry.createdAt else { return false }
                return entryDate >= today && entryDate < tomorrow
            }
        case .thisWeek:
            let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            return filtered.filter { entry in
                guard let entryDate = entry.createdAt else { return false }
                return entryDate >= weekStart
            }
        case .thisMonth:
            let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
            return filtered.filter { entry in
                guard let entryDate = entry.createdAt else { return false }
                return entryDate >= monthStart
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                // Mood Overview
                moodOverview
                
                // Journal Entries
                journalEntries
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEntry = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddJournalEntryView()
            }
            .sheet(isPresented: $showingEntryDetails) {
                if let entry = selectedEntry {
                    JournalEntryDetailView(entry: entry)
                }
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
                
                TextField("Search journal entries...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(JournalFilter.allCases, id: \.self) { filter in
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
    
    // MARK: - Mood Overview
    private var moodOverview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Mood Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("This Week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Mood Chart
            HStack(spacing: 16) {
                ForEach(MoodType.allCases, id: \.self) { mood in
                    VStack(spacing: 4) {
                        Text(mood.emoji)
                            .font(.title2)
                        
                        Text("\(moodCount(for: mood))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Journal Entries
    private var journalEntries: some View {
        Group {
            if filteredEntries.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredEntries, id: \.id) { entry in
                        JournalEntryRow(entry: entry) {
                            selectedEntry = entry
                            showingEntryDetails = true
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(emptyStateSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Write First Entry") {
                showingAddEntry = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Methods
    private func countForFilter(_ filter: JournalFilter) -> Int {
        switch filter {
        case .all:
            return entries.count
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            return entries.filter { entry in
                guard let entryDate = entry.createdAt else { return false }
                return entryDate >= today && entryDate < tomorrow
            }.count
        case .thisWeek:
            let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            return entries.filter { entry in
                guard let entryDate = entry.createdAt else { return false }
                return entryDate >= weekStart
            }.count
        case .thisMonth:
            let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
            return entries.filter { entry in
                guard let entryDate = entry.createdAt else { return false }
                return entryDate >= monthStart
            }.count
        }
    }
    
    private func moodCount(for mood: MoodType) -> Int {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return entries.filter { entry in
            guard let entryDate = entry.createdAt,
                  let entryMood = entry.mood else { return false }
            return entryDate >= weekStart && entryMood == mood.rawValue
        }.count
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredEntries[$0] }.forEach { entry in
                viewContext.delete(entry)
            }
            saveContext()
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "No journal entries yet"
        case .today:
            return "No entries today"
        case .thisWeek:
            return "No entries this week"
        case .thisMonth:
            return "No entries this month"
        }
    }
    
    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .all:
            return "Start writing to reflect on your day"
        case .today:
            return "Write about your day"
        case .thisWeek:
            return "No entries for this week yet"
        case .thisMonth:
            return "No entries for this month yet"
        }
    }
}

// MARK: - Journal Filter
enum JournalFilter: CaseIterable {
    case all, today, thisWeek, thisMonth
    
    var title: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        }
    }
}

// MARK: - Mood Types
enum MoodType: String, CaseIterable {
    case great = "great"
    case good = "good"
    case okay = "okay"
    case bad = "bad"
    case terrible = "terrible"
    
    var emoji: String {
        switch self {
        case .great: return "😄"
        case .good: return "🙂"
        case .okay: return "😐"
        case .bad: return "😔"
        case .terrible: return "😢"
        }
    }
    
    var color: Color {
        switch self {
        case .great: return .green
        case .good: return .blue
        case .okay: return .orange
        case .bad: return .red
        case .terrible: return .purple
        }
    }
}

// MARK: - Journal Entry Row
struct JournalEntryRow: View {
    let entry: JournalEntry
    let onTap: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Mood Indicator
                if let moodString = entry.mood,
                   let mood = MoodType(rawValue: moodString) {
                    Text(mood.emoji)
                        .font(.title2)
                }
                
                // Entry Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title ?? "Untitled Entry")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let content = entry.content, !content.isEmpty {
                        Text(content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(dateFormatter.string(from: entry.createdAt ?? Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Filter Pill (reused from TasksView)
struct FilterPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("(\(count))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct JournalView_Previews: PreviewProvider {
    static var previews: some View {
        JournalView()
            .environment(\.managedObjectContext, DataController().container.viewContext)
    }
}
