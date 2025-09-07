import Foundation
import SwiftUI
import WebKit

class GoodNotesService: ObservableObject {
    @Published var notebooks: [GoodNotesNotebook] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Notebook Management
    func addNotebook(for course: Course, sharingLink: String, name: String) {
        let notebook = GoodNotesNotebook(
            id: UUID(),
            name: name,
            sharingLink: sharingLink,
            classId: course.id,
            createdAt: Date()
        )
        
        notebooks.append(notebook)
        saveNotebooks()
    }
    
    func removeNotebook(_ notebook: GoodNotesNotebook) {
        notebooks.removeAll { $0.id == notebook.id }
        saveNotebooks()
    }
    
    func getNotebooks(for course: Course) -> [GoodNotesNotebook] {
        return notebooks.filter { $0.classId == course.id }
    }
    
    // MARK: - Link Validation
    func validateGoodNotesLink(_ link: String) -> Bool {
        // GoodNotes sharing links typically start with specific patterns
        let validPatterns = [
            "https://www.goodnotes.com/view/",
            "https://goodnotes.com/view/",
            "https://www.goodnotes.com/share/",
            "https://goodnotes.com/share/"
        ]
        
        return validPatterns.contains { link.hasPrefix($0) }
    }
    
    // MARK: - Data Persistence
    private func saveNotebooks() {
        if let encoded = try? JSONEncoder().encode(notebooks) {
            UserDefaults.standard.set(encoded, forKey: "goodnotes_notebooks")
        }
    }
    
    private func loadNotebooks() {
        if let data = UserDefaults.standard.data(forKey: "goodnotes_notebooks"),
           let decoded = try? JSONDecoder().decode([GoodNotesNotebook].self, from: data) {
            notebooks = decoded
        }
    }
    
    init() {
        loadNotebooks()
    }
}

// MARK: - GoodNotes Notebook Model
struct GoodNotesNotebook: Codable, Identifiable {
    let id: UUID
    let name: String
    let sharingLink: String
    let classId: UUID?
    let createdAt: Date
    var lastAccessed: Date?
    
    var displayName: String {
        return name.isEmpty ? "Untitled Notebook" : name
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }
}

// MARK: - GoodNotes WebView
struct GoodNotesWebView: UIViewRepresentable {
    let sharingLink: String
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: sharingLink) else {
            errorMessage = "Invalid GoodNotes link"
            return
        }
        
        isLoading = true
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: GoodNotesWebView
        
        init(_ parent: GoodNotesWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.errorMessage = nil
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.errorMessage = error.localizedDescription
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Notebook Browser View
struct NotebookBrowserView: View {
    let notebook: GoodNotesNotebook
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Done") {
                    // Dismiss view
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text(notebook.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // WebView
            ZStack {
                GoodNotesWebView(
                    sharingLink: notebook.sharingLink,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage
                )
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading notebook...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
                
                if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Failed to load notebook")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            // Retry loading
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [notebook.sharingLink])
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Add Notebook View
struct AddNotebookView: View {
    let course: Course
    @EnvironmentObject var goodNotesService: GoodNotesService
    @Environment(\.dismiss) private var dismiss
    
    @State private var notebookName = ""
    @State private var sharingLink = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Notebook Details") {
                    TextField("Notebook Name", text: $notebookName)
                    
                    TextField("GoodNotes Sharing Link", text: $sharingLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button("Add Notebook") {
                        addNotebook()
                    }
                    .disabled(notebookName.isEmpty || sharingLink.isEmpty)
                }
                
                Section("How to get a GoodNotes sharing link:") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Open your notebook in GoodNotes")
                        Text("2. Tap the share button (square with arrow)")
                        Text("3. Select 'Copy Link'")
                        Text("4. Paste the link above")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Notebook")
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
    
    private func addNotebook() {
        guard !notebookName.isEmpty else {
            errorMessage = "Please enter a notebook name"
            showingError = true
            return
        }
        
        guard !sharingLink.isEmpty else {
            errorMessage = "Please enter a sharing link"
            showingError = true
            return
        }
        
        guard goodNotesService.validateGoodNotesLink(sharingLink) else {
            errorMessage = "Please enter a valid GoodNotes sharing link"
            showingError = true
            return
        }
        
        goodNotesService.addNotebook(for: course, sharingLink: sharingLink, name: notebookName)
        dismiss()
    }
}
