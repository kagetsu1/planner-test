import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let appVersion = "1.0.0"
    private let buildNumber = "1"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App Icon and Name
                    VStack(spacing: 16) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Aera Flow")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Your Complete Academic Companion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Features
                    VStack(spacing: 20) {
                        Text("Features")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            FeatureRow(icon: "calendar", title: "Smart Calendar", description: "Sync with Moodle and manage your schedule")
                            FeatureRow(icon: "checklist", title: "Task Management", description: "Track assignments and deadlines")
                            FeatureRow(icon: "chart.bar", title: "Grade Tracking", description: "Monitor your academic performance")
                            FeatureRow(icon: "repeat", title: "Habit Tracker", description: "Build productive study habits")
                            FeatureRow(icon: "book", title: "Journaling", description: "Reflect on your academic journey")
                            FeatureRow(icon: "timer", title: "Pomodoro Timer", description: "Stay focused with time management")
                            FeatureRow(icon: "link", title: "GoodNotes Integration", description: "View your notes directly in the app")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Developer Info
                    VStack(spacing: 16) {
                        Text("Developed with ❤️")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            Text("Aera Flow Team")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Building tools for student success")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Links
                    VStack(spacing: 12) {
                        LinkButton(
                            title: "Privacy Policy",
                            icon: "hand.raised.fill",
                            action: { openPrivacyPolicy() }
                        )
                        
                        LinkButton(
                            title: "Terms of Service",
                            icon: "doc.text.fill",
                            action: { openTermsOfService() }
                        )
                        
                        LinkButton(
                            title: "Support & Feedback",
                            icon: "envelope.fill",
                            action: { openSupport() }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Copyright
                    VStack(spacing: 8) {
                        Text("© 2024 Aera Flow")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("All rights reserved")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func openPrivacyPolicy() {
        // In a real app, this would open the privacy policy URL
        print("Open Privacy Policy")
    }
    
    private func openTermsOfService() {
        // In a real app, this would open the terms of service URL
        print("Open Terms of Service")
    }
    
    private func openSupport() {
        // In a real app, this would open support/feedback
        print("Open Support")
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Link Button
struct LinkButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
