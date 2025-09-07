import SwiftUI
import EventKit

struct CalendarPermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var calendarService: CalendarService
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 80))
                    .foregroundColor(.themeAccent)

                VStack(spacing: 12) {
                    Text("Calendar Access Required")
                        .font(.title2).bold()
                        .multilineTextAlignment(.center)
                    Text("Aera Flow needs access to your calendar to sync your class schedule and create reminders for important events.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                VStack(spacing: 16) {
                    PermissionBenefitRow(icon: "clock",
                                         title: "Automatic Class Reminders",
                                         description: "Get notified before each class starts")
                    PermissionBenefitRow(icon: "calendar.badge.plus",
                                         title: "Sync with Moodle",
                                         description: "Import your course schedule automatically")
                    PermissionBenefitRow(icon: "bell",
                                         title: "Deadline Alerts",
                                         description: "Never miss an assignment due date")
                }
                .padding(.horizontal, 40)
                Spacer()

                VStack(spacing: 16) {
                    Button(action: {
                        calendarService.requestAccess()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            if calendarService.isAuthorized { dismiss() } else { showingSettings = true }
                        }
                    }) {
                        Text("Allow Calendar Access")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.themeAccent)
                            .cornerRadius(12)
                    }

                    Button(action: { showingSettings = true }) {
                        Text("Open Settings")
                            .font(.headline)
                            .foregroundColor(.themeAccent)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeAccent, lineWidth: 1))
                    }
                }.padding(.horizontal, 24)
            }
            .navigationTitle("Calendar Access")
            .onChange(of: showingSettings) { newValue in
                if newValue {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    showingSettings = false
                }
            }
        }
    }
}

struct PermissionBenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.themeAccent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
