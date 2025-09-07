//
// CourseDetailView+People.swift
// Adds a simple section to edit a Zoom/Meet link per Class (UserDefaults-based).

import SwiftUI

struct CourseMeetingLinkSection: View {
    let course: Course
    @ObservedObject var meetingLinks = MeetingLinkStore.shared
    @State private var linkText: String = ""

    var body: some View {
        Section("Online Meeting") {
            TextField("Zoom/Meet link (https://… or zoomus://…)", text: $linkText)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if let url = meetingLinks.link(for: course) {
                Link(destination: url) { Label("Join Meeting", systemImage: "video") }
            }
        }
        .onAppear {
            linkText = meetingLinks.link(for: course)?.absoluteString ?? ""
        }
        .onChange(of: linkText) { new in
            meetingLinks.setLink(new, for: course)
        }
    }
}
