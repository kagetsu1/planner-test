import SwiftUI

struct MoodleSetupView: View {
    @EnvironmentObject var moodleService: MoodleService
    @StateObject private var moodleAuthService = MoodleAuthService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var moodleURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Moodle Connection") {
                    TextField("Moodle URL", text: $moodleURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .placeholder(when: moodleURL.isEmpty) {
                            Text("https://your-university.moodle.edu")
                                .foregroundColor(.secondary)
                        }
                    
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                
                Section {
                    Button(action: connectToMoodle) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isConnecting ? "Connecting..." : "Connect to Moodle")
                        }
                    }
                    .disabled(moodleURL.isEmpty || username.isEmpty || password.isEmpty || isConnecting)
                }
                
                Section("Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Enter your Moodle site URL")
                        Text("2. Use your university credentials")
                        Text("3. The app will securely store your connection")
                        Text("4. You can sync classes, assignments, and grades")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Your credentials are stored securely on your device")
                        Text("• No data is shared with third parties")
                        Text("• You can disconnect at any time")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Moodle Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Connection Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Connection Successful", isPresented: $showingSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text("You're now connected to Moodle! You can sync your data from the Moodle Sync screen.")
            }
        }
    }
    
    private func connectToMoodle() {
        guard !moodleURL.isEmpty else {
            errorMessage = "Please enter your Moodle URL"
            showingError = true
            return
        }
        
        guard !username.isEmpty else {
            errorMessage = "Please enter your username"
            showingError = true
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            showingError = true
            return
        }
        
        isConnecting = true
        
        _Concurrency.Task {
            do {
                try await _Concurrency.Task.sleep(nanoseconds: 2_000_000_000) // Simulate delay
                try await moodleAuthService.authenticateWithCredentials(
                    baseURL: moodleURL, 
                    username: username, 
                    password: password
                )
                isConnecting = false
                showingSuccess = true
            } catch {
                isConnecting = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Placeholder Extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct MoodleSetupView_Previews: PreviewProvider {
    static var previews: some View {
        MoodleSetupView()
            .environmentObject(MoodleService())
    }
}
